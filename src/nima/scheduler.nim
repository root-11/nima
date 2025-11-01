
import deques, times, logging, tables, sets
import agent, agent_message, clock


type
  Scheduler* = ref object
    agents: Table[string, Agent]
    mailQueue: Deque[AgentMessage]
    clock: Clock  # Assuming Clock is a custom type
    logger: Logger
    running: bool
    subscriptions: Table[string, string]

proc initScheduler*(realTime: bool = true): Scheduler =
  # Constructor for Scheduler, mimicking Python's __init__
  new(result)
  result.agents = initTable[string, Agent]()
  result.mailQueue = initDeque[AgentMessage]()
  if realTime:
    result.clock = initRealTimeClock(result)  # Placeholder for real-time clock initialization
  else:
    result.clock = initSimulationClock(result)  # Placeholder for simulation clock initialization
  result.logger = newLogger("Scheduler")
  result.logger.setLevel(LOG_LEVEL)

proc add*(self: Scheduler, agent: Agent) =
  # Adds an agent to the scheduler
  if agent.uuid in self.agents:
    raise newException(SchedulerException, "Agent uuid already in usage.")
  self.agents[agent.uuid] = agent
  agent.schedulerApi = self
  agent.clock = self.clock
  agent.setup()

proc remove*(self: Scheduler, agentUuid: string) =
  # Removes an agent from the scheduler
  let agent = self.agents.getOrDefault(agentUuid)
  if agent.isNil:
    self.logger.error("Agent not found: " & agentUuid)
    return
  agent.teardown()
  self.agents.del(agentUuid)


proc run*(self: Scheduler, seconds: float = 0.0, iterations: int = 0, pauseIfIdle: bool = true, clearAlarmsAtEnd: bool = true) =
  self.running = true
  let startTime = times.getTime()
  var iterationCount = 0

  while self.running:
    # Process all messages before updating any agents
    if not self.mailQueue.isEmpty:
      for msg in self.mailQueue:
        let recipients = self.getMailingListRecipients(msg)  # Assuming getMailingListRecipients is implemented
        for recipient in recipients:
          self.agents[recipient].inbox.add(msg)
      self.mailQueue.clear()

    # Update all agents
    for agentId, agent in self.agents.pairs:
      agent.update()
      if agent.keepAwake:
        # Logic to handle keepAwake agents
        pass

    # Check for alarms and handle time progression
    self.clock.tick()  # Assuming tick method is correctly implemented
    self.clock.releaseAlarmMessages()

    # Check conditions to stop the scheduler
    if seconds > 0 and (times.getTime() - startTime) >= seconds:
      self.running = false
    if iterations > 0:
      iterationCount += 1
      if iterationCount >= iterations:
        self.running = false
    if pauseIfIdle and self.mailQueue.isEmpty:
      # Implement logic to pause if idle, based on conditions
      self.running = false

    if clearAlarmsAtEnd:
      # Clear all alarms if specified
      self.clock.clearAlarms()

    # Implement a short delay to prevent the loop from consuming too much CPU


proc pause*(self: Scheduler) =
  self.running = not self.running


type
  SubscriptionKey* = tuple[sender: string, receiver: string, topic: string]
  Subscriptions* = Table[SubscriptionKey, HashSet[string]]

proc subscribe*(self: Scheduler, subscriber: string, sender: string = "", receiver: string = "", topic: string = "") =
  let key = (sender, receiver, topic)
  if not self.subscriptions.hasKey(key):
    self.subscriptions[key] = initHashSet[string]()
  self.subscriptions[key].incl(subscriber)


proc unsubscribe*(self: Scheduler, subscriber: string, sender: string = "", receiver: string = "", topic: string = "", everything: bool = false) =
  if everything:
    # Remove the subscriber from all subscriptions
    for key, subscribers in self.subscriptions.pairs:
      subscribers.excl(subscriber)
      if subscribers.len == 0:
        self.subscriptions.del(key)
  else:
    let key = (sender, receiver, topic)
    if self.subscriptions.hasKey(key):
      self.subscriptions[key].excl(subscriber)
      # Optionally, clean up the key if there are no more subscribers
      if self.subscriptions[key].len == 0:
        self.subscriptions.del(key)
