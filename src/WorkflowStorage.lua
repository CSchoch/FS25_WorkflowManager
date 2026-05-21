--[[
    WorkflowManager - Workflow Storage
    Handles saving and loading workflows to/from XML files

    Author: WorkflowManager Team
]]

---@class WMStorage
WMStorage = {}

WMStorage.isInitialized = false
WMStorage.xmlFilename = "workflowManager.xml"

--- Deep-copy a support sub-step (strips any extra runtime fields)
local function deepCopySupportStep(step)
    return {
        type         = step.type,
        target       = step.target,
        action       = step.action,
        unloadTarget = step.unloadTarget,
        fillTypes    = step.fillTypes and {unpack(step.fillTypes)} or nil,
    }
end

--- Parse a comma-separated fill types string into an array. Returns nil if empty.
local function parseFillTypes(str)
    if str == nil or str == "" then return nil end
    local result = {}
    for part in string.gmatch(str, "([^,]+)") do
        table.insert(result, part)
    end
    return #result > 0 and result or nil
end

---Initialize the storage system
function WMStorage:init()
    self.isInitialized = true
    WMLogger:debug("WorkflowStorage initialized")
end

---Get the full path to the XML file for the current savegame
---@return string path Full path to XML file
function WMStorage:getXmlPath()
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        local savegamePath = g_currentMission.missionInfo.savegameDirectory
        if savegamePath ~= nil then
            return savegamePath .. "/" .. self.xmlFilename
        end
    end
    -- Fallback to mod directory for testing
    return WorkflowManager.modDirectory .. "/" .. self.xmlFilename
end

---Save all workflows to XML
---@param workflows table List of workflows to save
---@return boolean success True if saved successfully
function WMStorage:saveWorkflows(workflows)
    if workflows == nil then
        WMLogger:warning("No workflows to save")
        return false
    end

    local xmlPath = self:getXmlPath()
    WMLogger:info("Saving workflows to: %s", xmlPath)

    local xmlFile = XMLFile.create("workflowManager", xmlPath, "WorkflowManager")
    if xmlFile == nil then
        WMLogger:error("Failed to create XML file: %s", xmlPath)
        return false
    end

    -- Save each workflow
    for i, workflow in ipairs(workflows) do
        local workflowKey = string.format("WorkflowManager.workflows.workflow(%d)", i - 1)

        xmlFile:setString(workflowKey .. "#id", workflow.id)
        xmlFile:setString(workflowKey .. "#name", workflow.name)

        -- Save per-workflow AD settings (only write fields that are set)
        local s = workflow.adSettings
        if s and (s.unloadFillLevel ~= nil or s.pipeOffset ~= nil or s.preCallLevel ~= nil) then
            local sk = workflowKey .. ".adSettings"
            if s.unloadFillLevel ~= nil then xmlFile:setFloat(sk .. "#unloadFillLevel", s.unloadFillLevel) end
            if s.pipeOffset      ~= nil then xmlFile:setFloat(sk .. "#pipeOffset",      s.pipeOffset)      end
            if s.preCallLevel    ~= nil then xmlFile:setFloat(sk .. "#preCallLevel",     s.preCallLevel)    end
        end

        -- Save steps (with nested support sub-steps)
        for j, step in ipairs(workflow.steps) do
            local stepKey = string.format("%s.step(%d)", workflowKey, j - 1)
            xmlFile:setString(stepKey .. "#type", step.type)
            xmlFile:setString(stepKey .. "#target", step.target)
            xmlFile:setString(stepKey .. "#action", step.action or "default")

            -- AutoDrive advanced mode parameters
            if step.unloadTarget ~= nil and step.unloadTarget ~= "" then
                xmlFile:setString(stepKey .. "#unloadTarget", step.unloadTarget)
            end
            if step.fillTypes ~= nil and #step.fillTypes > 0 then
                xmlFile:setString(stepKey .. "#fillTypes", table.concat(step.fillTypes, ","))
            end

            -- Nested support sub-steps
            local supportSteps = step.support or {}
            for k, supportStep in ipairs(supportSteps) do
                local supportKey = string.format("%s.support(%d)", stepKey, k - 1)
                xmlFile:setString(supportKey .. "#type", supportStep.type)
                xmlFile:setString(supportKey .. "#target", supportStep.target)
                xmlFile:setString(supportKey .. "#action", supportStep.action or "default")

                if supportStep.unloadTarget ~= nil and supportStep.unloadTarget ~= "" then
                    xmlFile:setString(supportKey .. "#unloadTarget", supportStep.unloadTarget)
                end
                if supportStep.fillTypes ~= nil and #supportStep.fillTypes > 0 then
                    xmlFile:setString(supportKey .. "#fillTypes", table.concat(supportStep.fillTypes, ","))
                end
            end
        end
    end

    -- Save HUD position
    if WMHud.x ~= nil and WMHud.y ~= nil then
        xmlFile:setFloat("WorkflowManager.settings.hud#posX", WMHud.x)
        xmlFile:setFloat("WorkflowManager.settings.hud#posY", WMHud.y)
    end

    xmlFile:save()
    xmlFile:delete()

    WMLogger:info("Saved %d workflows", #workflows)
    return true
end

---Migrate old linked-workflow-pair format to hierarchical support format.
---Old format: two separate workflows with linkedWorkflowId/linkRole/syncGroup.
---New format: one workflow, each main step has step.support = {sub-steps}.
---@param workflows table Raw loaded workflow list (may contain old-format entries)
---@return table workflows Updated list (support workflows removed, steps enriched)
function WMStorage:migrateOldLinkedWorkflows(workflows)
    -- Quick check: is migration needed?
    local needsMigration = false
    for _, wf in ipairs(workflows) do
        if wf.linkRole ~= nil then
            needsMigration = true
            break
        end
    end
    if not needsMigration then return workflows end

    WMLogger:info("Old linked-workflow format detected — migrating to hierarchical support format...")

    -- Build ID lookup map
    local wfById = {}
    for _, wf in ipairs(workflows) do
        wfById[wf.id] = wf
    end

    local toRemove = {}
    local migratedCount = 0

    -- Process each main workflow
    for _, wf in ipairs(workflows) do
        if wf.linkRole == "main" and wf.linkedWorkflowId then
            local supportWf = wfById[wf.linkedWorkflowId]
            if supportWf and supportWf.linkRole == "support" and #supportWf.steps > 0 then
                -- Build syncGroup -> [support steps] map
                local groupSteps = {}
                for _, step in ipairs(supportWf.steps) do
                    local g = step.syncGroup
                    if g ~= nil then
                        if not groupSteps[g] then groupSteps[g] = {} end
                        table.insert(groupSteps[g], deepCopySupportStep(step))
                    end
                end

                -- Find the LAST main step index for each syncGroup
                -- (support steps go under the last main step of their group)
                local lastIndexForGroup = {}
                for i, step in ipairs(wf.steps) do
                    local g = step.syncGroup
                    if g ~= nil then
                        lastIndexForGroup[g] = i
                    end
                end

                -- Assign support sub-steps to the appropriate main step
                for g, idx in pairs(lastIndexForGroup) do
                    if groupSteps[g] then
                        wf.steps[idx].support = groupSteps[g]
                    end
                end

                toRemove[supportWf.id] = true
                migratedCount = migratedCount + 1
            else
                WMLogger:warning("Migration: main workflow '%s' has no valid support partner '%s' — keeping as standalone",
                    wf.name, tostring(wf.linkedWorkflowId))
            end
        end
    end

    -- Build new list, excluding absorbed support workflows
    local newWorkflows = {}
    for _, wf in ipairs(workflows) do
        if not toRemove[wf.id] then
            table.insert(newWorkflows, wf)
        end
    end

    -- Clean up all old link fields and ensure step.support = {} on every step
    for _, wf in ipairs(newWorkflows) do
        wf.linkedWorkflowId = nil
        wf.linkRole = nil
        for _, step in ipairs(wf.steps) do
            if step.support == nil then step.support = {} end
            step.syncGroup = nil
        end
    end

    if migratedCount > 0 then
        WMLogger:info("Migrated %d linked workflow pair(s) to hierarchical support format", migratedCount)
    end

    return newWorkflows
end

---Load all workflows from XML
---@return table workflows List of loaded workflows
function WMStorage:loadWorkflows()
    local workflows = {}
    local xmlPath = self:getXmlPath()

    -- Check if file exists
    if not fileExists(xmlPath) then
        WMLogger:info("No saved workflows found at: %s", xmlPath)
        return workflows
    end

    WMLogger:info("Loading workflows from: %s", xmlPath)

    local xmlFile = XMLFile.load("workflowManager", xmlPath)
    if xmlFile == nil then
        WMLogger:error("Failed to load XML file: %s", xmlPath)
        return workflows
    end

    -- Load workflows
    local workflowIndex = 0
    while true do
        local workflowKey = string.format("WorkflowManager.workflows.workflow(%d)", workflowIndex)

        -- Check if this workflow exists
        local workflowId = xmlFile:getString(workflowKey .. "#id")
        if workflowId == nil then
            break
        end

        local sk = workflowKey .. ".adSettings"
        local workflow = {
            id   = workflowId,
            name = xmlFile:getString(workflowKey .. "#name", "Unnamed Workflow"),
            -- currentStep and status are per-vehicle runtime state, not persisted
            steps = {},
            -- Legacy fields read for migration only (cleared after migrateOldLinkedWorkflows)
            linkedWorkflowId = xmlFile:getString(workflowKey .. "#linkedWorkflowId"),
            linkRole         = xmlFile:getString(workflowKey .. "#linkRole"),
            -- Per-workflow AD settings (nil fields = use AD's own default)
            adSettings = {
                unloadFillLevel = xmlFile:getFloat(sk .. "#unloadFillLevel"),
                pipeOffset      = xmlFile:getFloat(sk .. "#pipeOffset"),
                preCallLevel    = xmlFile:getFloat(sk .. "#preCallLevel"),
            },
        }

        -- Load steps
        local stepIndex = 0
        while true do
            local stepKey = string.format("%s.step(%d)", workflowKey, stepIndex)

            local stepType = xmlFile:getString(stepKey .. "#type")
            if stepType == nil then
                break
            end

            local step = {
                type         = stepType,
                target       = xmlFile:getString(stepKey .. "#target", ""),
                action       = xmlFile:getString(stepKey .. "#action", "default"),
                unloadTarget = xmlFile:getString(stepKey .. "#unloadTarget"),
                fillTypes    = parseFillTypes(xmlFile:getString(stepKey .. "#fillTypes"))
                               or parseFillTypes(xmlFile:getString(stepKey .. "#fillType")),
                -- Legacy syncGroup read for migration only
                syncGroup    = xmlFile:getInt(stepKey .. "#syncGroup"),
                support      = {},
            }

            -- Load nested support sub-steps
            local supportIndex = 0
            while true do
                local supportKey = string.format("%s.support(%d)", stepKey, supportIndex)
                local supportType = xmlFile:getString(supportKey .. "#type")
                if supportType == nil then
                    break
                end

                local supportStep = {
                    type         = supportType,
                    target       = xmlFile:getString(supportKey .. "#target", ""),
                    action       = xmlFile:getString(supportKey .. "#action", "default"),
                    unloadTarget = xmlFile:getString(supportKey .. "#unloadTarget"),
                    fillTypes    = parseFillTypes(xmlFile:getString(supportKey .. "#fillTypes"))
                                   or parseFillTypes(xmlFile:getString(supportKey .. "#fillType")),
                }
                table.insert(step.support, supportStep)
                supportIndex = supportIndex + 1
            end

            table.insert(workflow.steps, step)
            stepIndex = stepIndex + 1
        end

        table.insert(workflows, workflow)
        workflowIndex = workflowIndex + 1
    end

    -- Migrate old linked-workflow-pair format to hierarchical support format
    workflows = self:migrateOldLinkedWorkflows(workflows)

    -- Load HUD position
    local hudX = xmlFile:getFloat("WorkflowManager.settings.hud#posX")
    local hudY = xmlFile:getFloat("WorkflowManager.settings.hud#posY")
    if hudX ~= nil and hudY ~= nil then
        WMHud.x = hudX
        WMHud.y = hudY
        WMLogger:info("Restored HUD position: x=%.4f y=%.4f", hudX, hudY)
    end

    xmlFile:delete()

    WMLogger:info("Loaded %d workflows", #workflows)
    return workflows
end
