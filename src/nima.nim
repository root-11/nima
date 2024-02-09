# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

type
  Message* = object
    sender*: int
    receiver*: int
    topic*: string


proc newMessage*(sender,receiver:int, topic:string): Message = 
  result.sender = sender
  result.receiver = receiver
  result.topic = topic


proc copy*(self: Message): Message = 
  result.sender = self.sender
  result.receiver = self.receiver
  result.topic = self.topic

var agent_ids: int = 0

type Agent* = object
  id*: int

proc newAgent*(): Agent = 
  agent_ids += 1
  result.id = agent_ids

type Scheduler* = object
  agents*: seq[Agent]
  t*: int = 0

proc newScheduler*(): Scheduler = 
  result.t = 0

proc add*(scheduler: var Scheduler, agent: var Agent) =
  # Adds agent to the scheduler
  scheduler.agents.add(agent)

proc run*(self: var Scheduler) = 
  let step: int = 1
  self.t += step