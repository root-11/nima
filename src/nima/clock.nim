import times, logging, tables, sequtils, std/[collections/deques]
import scheduler, agent, agent_message

type
  AlarmRegistry* = object  # Placeholder, assuming AlarmRegistry is defined elsewhere
    # Define necessary properties and methods

type
  # Assuming Scheduler, AgentMessage, and other necessary types are defined elsewhere
  Clock* = ref object
    schedulerApi: Scheduler
    time: float
    registry: Table[string, AlarmRegistry]  # Placeholder for AlarmRegistry definition
    alarmTime: seq[float]
    clientsToWakeUp: Table[float, Table[string, bool]]
    lastRequiredAlarm: float

proc initClock*(schedulerApi: Scheduler): Clock =
  if schedulerApi.isNil:
    raise newException(ValueError, "Scheduler API cannot be nil")
  new(result)
  result.schedulerApi = schedulerApi
  result.time = 0.0  # Initial time setup can vary
  result.registry = initTable[string, AlarmRegistry]()
  result.alarmTime = @[]
  result.clientsToWakeUp = initTable[float, Table[string, bool]]()
  result.lastRequiredAlarm = -1.0

method tick*(self: Clock) {.base.} =
  # Base method for ticking the clock; to be overridden in subclasses
  raise newException(ValueError, "Tick method not implemented.")

type
  RealTimeClock* = ref object of Clock

proc initRealTimeClock*(schedulerApi: Scheduler): RealTimeClock =
  new(result)
  result.schedulerApi = schedulerApi
  # Initialize real-time clock specific fields if any

method tick*(self: RealTimeClock) =
  # Implementation for RealTimeClock ticking
  self.time = getTime().toUnixFloat()  # Set to current real time

type
  SimulationClock* = ref object of Clock
    # Additional fields specific to SimulationClock if needed

proc initSimulationClock*(schedulerApi: Scheduler): SimulationClock =
  new(result)
  result.schedulerApi = schedulerApi
  # Initialize simulation clock specific fields if any

method tick*(self: SimulationClock) =
  # Implementation for SimulationClock ticking
  self.time += 1.0  # Example: Increment time by 1.0 for each tick


proc releaseAlarmMessages*(self: Clock) =
  var i = 0
  while i < len(self.alarmTime):
    let timestamp = self.alarmTime[i]
    if timestamp > self.time:
      break

    if self.clientsToWakeUp.contains(timestamp):
      for client, _ in self.clientsToWakeUp[timestamp]:
        if self.registry.contains(client):
          let registry = self.registry[client]
          # Extend your mail queue here with messages from registry.releaseAlarm(timestamp)
          # Assuming Scheduler has a method to add messages to its mail queue
          self.schedulerApi.addMessagesToMailQueue(registry.releaseAlarm(timestamp))

      self.clientsToWakeUp.del(timestamp)
      self.alarmTime.del(i)
    else:
      i.inc()


proc setAlarm*(self: Clock, delay: float, alarmMessage: AgentMessage, ignoreAlarmIfIdle: bool) =
  let wakeupTime = self.time + delay
  if not ignoreAlarmIfIdle:
    self.lastRequiredAlarm = max(self.lastRequiredAlarm, wakeupTime)

  if wakeupTime not in self.alarmTime:
    self.alarmTime.add(wakeupTime)
    self.alarmTime.sort()

  var registry = self.registry.getOrDefault(alarmMessage.receiver)
  registry.setAlarm(wakeupTime, alarmMessage)
  self.registry[alarmMessage.receiver] = registry
  self.clientsToWakeUp[wakeupTime][alarmMessage.receiver] = true


proc listAlarms*(self: Clock, receiver: string): seq[tuple[time: float, message: AgentMessage]] =
  var alarms: seq[tuple[time: float, message: AgentMessage]] = @[]
  if self.registry.contains(receiver):
    let registry = self.registry[receiver]
    # Assuming AlarmRegistry has a method to list alarms
    alarms = registry.listAlarms()
  return alarms


proc clearAlarms*(self: Clock, receiver: string = "", topic: string = "") =
  if receiver != "":
    if self.registry.contains(receiver):
      let registry = self.registry[receiver]
      registry.clearAlarms(topic) # Assuming AlarmRegistry has a method to clear alarms by topic
      # Further clean up in self.clientsToWakeUp and self.alarmTime as necessary
  else:
    self.alarmTime.clear()
    self.clientsToWakeUp.clear()





