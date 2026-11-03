class_name EmployeeProfile
extends Resource
## Stable identity of one employee (data only in Phase 1). The same id
## follows the worker through jobs, seats, fear, firing and departure.

@export var employee_id := ""
@export var display_name := ""
@export var appearance: HumanAppearance
@export var primary_trait := ""
@export var secondary_trait := ""
@export var hired_day := 1
@export var bed_anchor := ""                 # e.g. "WorkerBed_1"
