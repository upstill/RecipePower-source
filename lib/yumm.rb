def ingreds
  # debugger
  file = File.read "yumm.json"
  data = JSON.parse file
  x=2
  data
end
