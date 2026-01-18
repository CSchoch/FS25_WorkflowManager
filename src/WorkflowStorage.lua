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
        xmlFile:setInt(workflowKey .. "#currentStep", workflow.currentStep)
        xmlFile:setString(workflowKey .. "#status", workflow.status)

        -- Save vehicle reference (by ID if available)
        if workflow.vehicle ~= nil and workflow.vehicle.id ~= nil then
            xmlFile:setInt(workflowKey .. "#vehicleId", workflow.vehicle.id)
        end

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
            currentStep = xmlFile:getInt(workflowKey .. "#currentStep", 1),
            status = xmlFile:getString(workflowKey .. "#status", WorkflowManager.STATUS_READY),
            vehicle = nil,
            steps = {}
        }

        -- Try to restore vehicle reference
        local vehicleId = xmlFile:getInt(workflowKey .. "#vehicleId")
        if vehicleId ~= nil then
            workflow.vehicle = self:findVehicleById(vehicleId)
        end

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

        -- Reset status if it was running (can't resume mid-step after reload)
        if workflow.status == WorkflowManager.STATUS_RUNNING then
            workflow.status = WorkflowManager.STATUS_PAUSED
        end

        table.insert(workflows, workflow)
        workflowIndex = workflowIndex + 1
    end

    xmlFile:delete()

    WMLogger:info("Loaded %d workflows", #workflows)
    return workflows
end

---Find a vehicle by its ID
---@param vehicleId number Vehicle ID
---@return table|nil vehicle Vehicle object or nil
function WMStorage:findVehicleById(vehicleId)
    if g_currentMission == nil or g_currentMission.vehicles == nil then
        return nil
    end

    for _, vehicle in ipairs(g_currentMission.vehicles) do
        if vehicle.id == vehicleId then
            return vehicle
        end
    end

    return nil
end

---Export a workflow to a standalone XML file
---@param workflow table Workflow to export
---@param filename string Target filename
---@return boolean success True if exported successfully
function WMStorage:exportWorkflow(workflow, filename)
    if workflow == nil then
        return false
    end

    local exportPath = WorkflowManager.modDirectory .. "exports/" .. filename
    WMLogger:info("Exporting workflow to: %s", exportPath)

    local xmlFile = XMLFile.create("workflowExport", exportPath, "Workflow")
    if xmlFile == nil then
        WMLogger:error("Failed to create export file: %s", exportPath)
        return false
    end

    xmlFile:setString("Workflow#id", workflow.id)
    xmlFile:setString("Workflow#name", workflow.name)

    for j, step in ipairs(workflow.steps) do
        local stepKey = string.format("Workflow.step(%d)", j - 1)
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

    xmlFile:save()
    xmlFile:delete()

    return true
end

---Import a workflow from a standalone XML file
---@param filename string Source filename
---@return table|nil workflow Imported workflow or nil
function WMStorage:importWorkflow(filename)
    local importPath = WorkflowManager.modDirectory .. "exports/" .. filename

    if not fileExists(importPath) then
        WMLogger:error("Import file not found: %s", importPath)
        return nil
    end

    local xmlFile = XMLFile.load("workflowImport", importPath)
    if xmlFile == nil then
        WMLogger:error("Failed to load import file: %s", importPath)
        return nil
    end

    local workflow = {
        id = WorkflowManager:generateWorkflowId(), -- Generate new ID
        name = xmlFile:getString("Workflow#name", "Imported Workflow"),
        currentStep = 1,
        status = WorkflowManager.STATUS_READY,
        vehicle = nil,
        steps = {}
    }

    local stepIndex = 0
    while true do
        local stepKey = string.format("Workflow.step(%d)", stepIndex)

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

    xmlFile:delete()

    WMLogger:info("Imported workflow: %s with %d steps", workflow.name, #workflow.steps)
    return workflow
end
