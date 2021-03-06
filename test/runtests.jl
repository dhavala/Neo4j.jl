using Neo4j
using Base.Test


c = Connection(user="neo4j", password="neo4j")

loadtx = transaction(c)

function createnode(txn, name, age; submit=false)
  q = "CREATE (n:Neo4jjl) SET n.name = {name}, n.age = {age}"
  txn(q, "name" => name, "age" => age; submit=submit)
end

@test length(loadtx.statements) == 0

createnode(loadtx, "John Doe", 20)

@test length(loadtx.statements) == 1

createnode(loadtx, "Jane Doe", 20)

@test length(loadtx.statements) == 2

people = loadtx("MATCH (n:Neo4jjl) WHERE n.age = {age} RETURN n.name", "age" => 20; submit=true)

@test length(loadtx.statements) == 0
@test length(people.results) == 3
@test length(people.errors) == 0

matchresult = people.results[3]
@test matchresult["columns"][1] == "n.name"
@test "John Doe" in [row["row"][1] for row = matchresult["data"]]
@test "Jane Doe" in [row["row"][1] for row = matchresult["data"]]

loadresult = commit(loadtx)

@test length(loadresult.results) == 0
@test length(loadresult.errors) == 0

deletetx = transaction(c)

deletetx("MATCH (n:Neo4jjl) WHERE n.age = {age} DELETE n", "age" => 20)

deleteresult = commit(deletetx)

@test length(deleteresult.results) == 1
@test length(deleteresult.results[1]["columns"]) == 0
@test length(deleteresult.results[1]["data"]) == 0
@test length(deleteresult.errors) == 0

rolltx = transaction(c)

person = createnode(rolltx, "John Doe", 20; submit=true)

@test length(rolltx.statements) == 0
@test length(person.results) == 1
@test length(person.errors) == 0

rollback(rolltx)

rolltx = transaction(c)
rollresult = rolltx("MATCH (n:Neo4jjl) WHERE n.name = 'John Doe' RETURN n"; submit=true)

@test length(rollresult.results) == 1
@test length(rollresult.results[1]["columns"]) == 1
@test length(rollresult.results[1]["data"]) == 0
@test length(rollresult.errors) == 0


@test isdefined(:Neo4j) == true
@test typeof(Neo4j) == Module

graph = getgraph("neo4j","neo4j")
@test startswith(graph.version, "2.3.0") == true
@test graph.node == "http://localhost:7474/db/data/node"

barenode = createnode(graph)
@test barenode.self == "http://localhost:7474/db/data/node/$(barenode.id)"

propnode = createnode(graph, Dict{AbstractString,Any}("a" => "A", "b" => 1))
@test propnode.data["a"] == "A"
@test propnode.data["b"] == 1

gotnode = getnode(graph, propnode.id)
@test gotnode.id == propnode.id
@test gotnode.data["a"] == "A"
@test gotnode.data["b"] == 1

setnodeproperty(barenode, "a", "A")
barenode = getnode(barenode)
@test barenode.data["a"] == "A"

props = getnodeproperties(propnode)
@test props["a"] == "A"
@test props["b"] == 1
@test length(props) == 2

updatenodeproperties(barenode, Dict{AbstractString,Any}("a" => 1, "b" => "A"))
barenode = getnode(barenode)
@test barenode.data["a"] == 1
@test barenode.data["b"] == "A"

updatefewnodeproperties(barenode, Dict{AbstractString,Any}("a" => 2))
barenode = getnode(barenode)
@test barenode.data["a"] == 2
@test barenode.data["b"] == "A"


deletenodeproperties(barenode)
barenode = getnode(barenode)
@test length(barenode.data) == 0

deletenodeproperty(propnode, "b")
propnode = getnode(propnode)
@test length(propnode.data) == 1
@test propnode.data["a"] == "A"

addnodelabel(barenode, "A")
barenode = getnode(barenode)
@test getnodelabels(barenode) == ["A"]

addnodelabels(barenode, ["B", "C"])
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "A" in labels
@test "B" in labels
@test "C" in labels
@test length(labels) == 3

updatenodelabels(barenode, ["D", "E", "F"])
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "D" in labels
@test "E" in labels
@test "F" in labels
@test length(labels) == 3

deletenodelabel(barenode, "D")
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "E" in labels
@test "F" in labels
@test length(labels) == 2

nodes = getnodesforlabel(graph, "E")
@test length(nodes) > 0
@test barenode.id in [n.id for n = nodes]

labels = getlabels(graph)
# TODO Can't really test this because there might be other crap in the local DB

rel1 = createrel(barenode, propnode, "test"; props=Dict{AbstractString,Any}("a" => "A", "b" => 1))
rel1alt = getrel(graph, rel1.id)
@test rel1.reltype == "TEST"
@test rel1.data["a"] == "A"
@test rel1.data["b"] == 1
@test rel1.id == rel1alt.id

rel1prop = getrelproperties(rel1)
@test rel1prop["a"] == "A"
@test rel1prop["b"] == 1
@test length(rel1prop) == 2

@test getrelproperty(rel1, "a") == "A"
@test getrelproperty(rel1, "b") == 1

updaterelproperties(rel1,Dict{AbstractString,Any}("a" => "AA","b"=>"BB"))
@test getrelproperty(rel1, "a") == "AA"
@test getrelproperty(rel1, "b") == "BB"

updatefewrelproperties(rel1,Dict{AbstractString,Any}("a" => "A"))
@test getrelproperty(rel1, "a") == "A"
@test getrelproperty(rel1, "b") == "BB"



deleterel(rel1)
@test_throws ErrorException getrel(graph, rel1.id)
@test getrel(graph, rel1.id)

deletenode(graph, barenode.id)
deletenode(graph, propnode.id)
@test_throws ErrorException getnode(graph, barenode.id)
@test_throws ErrorException getnode(graph, propnode.id)
