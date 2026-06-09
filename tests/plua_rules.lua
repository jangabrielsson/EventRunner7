--%%file:tests/plua.lua,plua

print("OKOKOK")
function main(er)
  print("OKOK")
  rule("@@00:00:05 => log('tick!')",{check=false})
end