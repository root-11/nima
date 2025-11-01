import unittest
import nima/agent
import nima/agent_message
import nima/scheduler


import unittest
import ../src/agent  # Adjust the import path based on your project structure

suite "Agent Tests":
  test "Agent initialization":
    let agent = initAgent("testUUID")
    check agent.uuid == "testUUID"
    check agent.inbox.len == 0

  test "Send and receive messages":
    # Assuming Scheduler and AgentMessage are implemented
    var scheduler = initScheduler(realTime=false)
    let sender = initAgent("senderUUID")
    let receiver = initAgent("receiverUUID")
    scheduler.add(sender)
    scheduler.add(receiver)

    let msg = AgentMessage(sender: sender.uuid, receiver: receiver.uuid, topic: "Test", direct: true)
    sender.send(msg, scheduler)
    
    scheduler.run()  # This might need adjustments based on your scheduler's implementation

    let receivedMsg = receiver.receive()
    check receivedMsg != nil
    check receivedMsg.topic == "Test"

  # Add more tests for other functionalities


suite "Agent and Message Tests":
  setup:
    # Setup code before each test, if necessary

  teardown:
    # Teardown code after each test, if necessary

  test "Message creation and attributes":
    var msg = initAgentMessage("1")
    check msg.sender == "1"
    check msg.receiver == ""
    check msg.topic == "TrialMessage"  # Assuming you have logic to set this

  test "Direct message constraints":
    var msg = initAgentMessage("1", "2", direct=true)
    check msg.sender == "1"
    check msg.receiver == "2"
    check msg.direct == true

    # To simulate the try-except block for exception testing in Nim:
    var raisedError = false
    try:
      var msg2 = initAgentMessage("1", direct=true)  # This should fail if direct messages require a receiver
    except ValueError:
      raisedError = true
    check raisedError == true


suite "Scheduler Functionality Tests":

  test "Agent Registration and Deregistration":
    var sched = initScheduler(realTime=false)
    let agent = initAgent("agent1")
    sched.add(agent)
    check sched.agents.hasKey("agent1")
    sched.remove("agent1")
    check not sched.agents.hasKey("agent1")

  test "Clock and Timing":
    var sched = initScheduler(realTime=false)
    sched.clock.tick()  # Advance time by one tick
    check sched.clock.time > 0  # Assuming clock starts at 0

  # Additional tests go here


test "Complex Messaging Scenario":
  var scheduler = initScheduler(realTime=false)
  let agentA = initAgent("AgentA")
  let agentB = initAgent("AgentB")
  let agentC = initAgent("AgentC")
  scheduler.add(agentA)
  scheduler.add(agentB)
  scheduler.add(agentC)

  # AgentA sends a broadcast message
  let broadcastMsg = AgentMessage(sender: agentA.uuid, topic: "Broadcast", direct: false)
  agentA.send(broadcastMsg, scheduler)

  # AgentB sends a direct message to AgentC
  let directMsg = AgentMessage(sender: agentB.uuid, receiver: agentC.uuid, topic: "Direct", direct: true)
  agentB.send(directMsg, scheduler)

  scheduler.run()

  # Verify that AgentB and AgentC received the broadcast message
  check not agentB.receive().isNil
  check not agentC.receive().isNil

  # Verify that AgentC received the direct message
  let receivedDirectMsg = agentC.receive()
  check receivedDirectMsg.topic == "Direct"

import unittest
import yourmodule  # Import your Nim project's relevant modules

suite "Complex Scheduling Algorithm Tests":

  test "Test complex scheduling algorithm":
    var scheduler = initScheduler(realTime=false)
    # Setup machines, stock agent, and order as per Python example
    let m2 = initMachine(name="M2", runTimes=m2Runtimes, transformations=m2Transformations)
    let order = initOrder(sender=m2, receiver=m2, orderItems=...)
    m2.inbox.add(order)
    let m1 = initMachine(name="M1", runTimes=m1Runtimes, transformations=m1Transformations)
    let stockAgent = initStockAgent()
    # Set relationships
    # Assuming setCustomer, setSupplier, and similar methods are implemented
    stockAgent.setCustomer(m1)
    m2.setSupplier(m1)
    m1.setCustomer(m2)
    m1.setSupplier(stockAgent)

    # Add agents to the scheduler and run
    for agent in [m1, m2, stockAgent]:
      scheduler.add(agent)
    scheduler.run(pauseIfIdle=true)

    # Check the sequence of completed jobs
    var checkSequence = @["A", "E", "B", "D", "G", "F", "C"]
    for idx, job in enumerate(m2.jobs):
      check job.orderSku == checkSequence[idx]
