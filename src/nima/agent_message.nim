type
  AgentMessage = ref object
    sender, receiver: string  # Assuming UUIDs are strings for simplicity
    topic: string
    direct: bool

proc initAgentMessage(sender, receiver: string, topic: string = "", direct: bool = false): AgentMessage =
  # Mimics the Python __init__ method functionality
  new(result)
  if sender != "":
    result.sender = sender
  if receiver != "":
    result.receiver = receiver
  if topic != "":
    result.topic = topic
  result.direct = direct

proc `[]`(self: AgentMessage, key: string): string =
  # Mimics Python's dynamic attribute access, limited to string attributes for simplicity
  case key
  of "sender": result = self.sender
  of "receiver": result = self.receiver
  of "topic": result = self.topic
  else: raise newException(ValueError, "Invalid key: " & key)

proc `$`(self: AgentMessage): string =
  # Mimics the Python __str__ method
  "From -> To : " & self.sender & " -> " & self.receiver & " Topic: " & self.topic & " Direct: " & $self.direct
