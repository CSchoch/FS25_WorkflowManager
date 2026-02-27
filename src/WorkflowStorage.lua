--[[
    WorkflowManager - Workflow Storage
    Handles saving and loading workflows to/from XML files

    Author: WorkflowManager Team
]]

---@class WMStorage
WMStorage = {}

WMStorage.isInitialized = false
WMStorage.xmlFilename = "workflowManager.xml"

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
    return WorkflowManager.modDirectory .. self.xmlFilename
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

        -- Milestone 4: Vehicle is no longer saved with workflow
        -- Vehicle is detected at runtime when starting the workflow

        -- Save steps
        for j, step in ipairs(workflow.steps) do
            local stepKey = string.format("%s.step(%d)", workflowKey, j - 1)
            xmlFile:setString(stepKey .. "#type", step.type)
            xmlFile:setString(stepKey .. "#target", step.target)
            xmlFile:setString(stepKey .. "#action", step.action or "default")

            -- AutoDrive advanced mode parameters
            if step.unloadTarget ~= nil and step.unloadTarget ~= "" then
                xmlFile:setString(stepKey .. "#unloadTarget", step.unloadTarget)
            end
            if step.fillType ~= nil and step.fillType ~= "" then
                xmlFile:setString(stepKey .. "#fillType", step.fillType)
            end
        end
    end

    xmlFile:save()
    xmlFile:delete()

    WMLogger:info("Saved %d workflows", #workflows)
    return true
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

        local workflow = {
            id = workflowId,
            name = xmlFile:getString(workflowKey .. "#name", "Unnamed Workflow"),
            -- currentStep and status are per-vehicle runtime state, not persisted
            -- Vehicle is detected at runtime when starting the workflow
            steps = {}
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
                type = stepType,
                target = xmlFile:getString(stepKey .. "#target", ""),
                action = xmlFile:getString(stepKey .. "#action", "default"),
                -- AutoDrive advanced mode parameters
                unloadTarget = xmlFile:getString(stepKey .. "#unloadTarget"),
                fillType = xmlFile:getString(stepKey .. "#fillType")
            }

            table.insert(workflow.steps, step)
            stepIndex = stepIndex + 1
        end

        table.insert(workflows, workflow)
        workflowIndex = workflowIndex + 1
    end

    xmlFile:delete()

    WMLogger:info("Loaded %d workflows", #workflows)
    return workflows
end

