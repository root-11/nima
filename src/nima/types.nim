import uuids

type
  # Custom types for your project
  UUID* = string  # Simplified UUID representation
  DateTime* = object  # If you need custom time handling
    year: int
    month: int
    day: int
    hour: int
    minute: int
    second: int

const
  # Common constants
  DefaultAgentCapacity* = 100

# Custom exceptions that might be used across modules
type
  AgentException* = object of Exception
  SchedulerException* = object of Exception

# Utility functions, e.g., for handling time or generating UUIDs
proc generateUUID*(): UUID =
  result = $generateUUID()


proc currentTime*(): DateTime =
  # This is a placeholder. Replace it with actual logic to get the current time.
  result.year = 2020
  result.month = 1
  result.day = 1
  result.hour = 0
  result.minute = 0
  result.second = 0
