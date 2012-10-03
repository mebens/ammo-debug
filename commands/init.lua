local path = ({...})[1]:gsub("%.init", "")
debug.include(require(path .. ".debug"))
debug.include(require(path .. ".world"))
