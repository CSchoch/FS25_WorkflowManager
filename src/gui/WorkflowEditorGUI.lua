--[[
    WorkflowManager - Workflow Editor GUI
    Allows editing workflow details and steps

    Author: WorkflowManager Team
]]

---@class WMEditorGUI
WMEditorGUI = {}

WMEditorGUI.isVisible = false
WMEditorGUI.currentWorkflow = nil
WMEditorGUI.selectedStepIndex = 0

---Initialize the editor GUI
function WMEditorGUI:init()
    WMLogger:debug("WorkflowEditorGUI initialized")
end

---Open the editor for a workflow
---@param workflow table Workflow to edit
function WMEditorGUI:openWorkflow(workflow)
    if workflow == nil then
        WMLogger:error("Cannot open editor - workflow is nil")
        return
    end

    self.currentWorkflow = workflow
    self.selectedStepIndex = 0
    self.isVisible = true

    WMLogger:debug("Opened editor for workflow: %s", workflow.name)
end

---Close the editor
function WMEditorGUI:close()
    self.isVisible = false
    self.currentWorkflow = nil
    self.selectedStepIndex = 0

    WMLogger:debug("Closed workflow editor")
end

---Save changes and close
function WMEditorGUI:saveAndClose()
    if self.currentWorkflow ~= nil then
        WMLogger:info("Saved workflow: %s", self.currentWorkflow.name)
    end
    self:close()

    -- Refresh main GUI
    WMManagerGUI:refresh()
end

---Cancel changes and close
function WMEditorGUI:cancelAndClose()
    -- TODO: Implement undo of changes
    self:close()
end

---Set workflow name
---@param name string New workflow name
function WMEditorGUI:setWorkflowName(name)
    if self.currentWorkflow ~= nil then
        self.currentWorkflow.name = name
    end
end

---Assign vehicle to workflow
---@param vehicle table Vehicle to assign
function WMEditorGUI:assignVehicle(vehicle)
    if self.currentWorkflow ~= nil then
        self.currentWorkflow.vehicle = vehicle
        WMLogger:debug("Assigned vehicle to workflow")
    end
end

---Add a new step to the workflow
---@param stepType string Step type (autodrive/courseplay)
---@param target string Target route/course name
---@param action string|nil Action type
function WMEditorGUI:addStep(stepType, target, action)
    if self.currentWorkflow == nil then
        return
    end

    local step = {
        type = stepType,
        target = target,
        action = action or "default"
    }

    table.insert(self.currentWorkflow.steps, step)
    WMLogger:debug("Added step: %s -> %s", stepType, target)
end

---Remove selected step
function WMEditorGUI:removeSelectedStep()
    if self.currentWorkflow == nil or self.selectedStepIndex <= 0 then
        return
    end

    table.remove(self.currentWorkflow.steps, self.selectedStepIndex)
    self.selectedStepIndex = 0
    WMLogger:debug("Removed step")
end

---Move selected step up
function WMEditorGUI:moveStepUp()
    if self.currentWorkflow == nil or self.selectedStepIndex <= 1 then
        return
    end

    local steps = self.currentWorkflow.steps
    local temp = steps[self.selectedStepIndex]
    steps[self.selectedStepIndex] = steps[self.selectedStepIndex - 1]
    steps[self.selectedStepIndex - 1] = temp

    self.selectedStepIndex = self.selectedStepIndex - 1
end

---Move selected step down
function WMEditorGUI:moveStepDown()
    if self.currentWorkflow == nil then
        return
    end

    local steps = self.currentWorkflow.steps
    if self.selectedStepIndex <= 0 or self.selectedStepIndex >= #steps then
        return
    end

    local temp = steps[self.selectedStepIndex]
    steps[self.selectedStepIndex] = steps[self.selectedStepIndex + 1]
    steps[self.selectedStepIndex + 1] = temp

    self.selectedStepIndex = self.selectedStepIndex + 1
end

---Get available AutoDrive destinations for dropdown
---@return table destinations List of destination names
function WMEditorGUI:getAutoDriveDestinations()
    return ADIntegration:getDestinations()
end

---Get available Courseplay courses for dropdown
---@return table courses List of course names
function WMEditorGUI:getCourseplayCourses()
    return CPIntegration:getCourses()
end

---Get available vehicles for dropdown
---@return table vehicles List of vehicles with AD/CP support
function WMEditorGUI:getAvailableVehicles()
    local vehicles = {}

    if g_currentMission == nil or g_currentMission.vehicles == nil then
        return vehicles
    end

    for _, vehicle in ipairs(g_currentMission.vehicles) do
        -- Check if vehicle has AutoDrive or Courseplay
        local hasAD = vehicle.ad ~= nil
        local hasCP = vehicle.spec_courseplay ~= nil or vehicle.cp ~= nil

        if hasAD or hasCP then
            table.insert(vehicles, {
                vehicle = vehicle,
                name = vehicle:getName() or "Unknown Vehicle",
                hasAD = hasAD,
                hasCP = hasCP
            })
        end
    end

    return vehicles
end

---Draw the editor GUI
function WMEditorGUI:draw()
    if not self.isVisible or self.currentWorkflow == nil then
        return
    end

    local workflow = self.currentWorkflow

    -- Draw header
    setTextColor(1, 1, 1, 1)
    setTextBold(true)
    renderText(0.3, 0.9, 0.025, "Edit Workflow: " .. workflow.name)
    setTextBold(false)

    -- Draw workflow info
    local vehicleName = "None"
    if workflow.vehicle ~= nil then
        vehicleName = workflow.vehicle:getName() or "Unknown"
    end
    renderText(0.3, 0.85, 0.018, "Vehicle: " .. vehicleName)

    -- Draw steps
    renderText(0.3, 0.80, 0.020, "Steps:")

    local y = 0.75
    for i, step in ipairs(workflow.steps) do
        local color = {1, 1, 1, 1}
        if i == self.selectedStepIndex then
            color = {0.2, 0.8, 0.2, 1}
        end
        setTextColor(color[1], color[2], color[3], color[4])

        local stepText = string.format("%d. [%s] %s (%s)",
            i, step.type:upper(), step.target, step.action)
        renderText(0.3, y, 0.016, stepText)

        y = y - 0.025
    end

    if #workflow.steps == 0 then
        setTextColor(0.7, 0.7, 0.7, 1)
        renderText(0.3, y, 0.016, "No steps defined")
    end

    -- Draw controls hint
    setTextColor(0.8, 0.8, 0.8, 1)
    renderText(0.3, 0.15, 0.015, "Press ESC to close editor")
end

---Update function
---@param dt number Delta time
function WMEditorGUI:update(dt)
    if not self.isVisible then
        return
    end

    -- Handle input
    -- Full implementation will use proper GUI input handling
end
