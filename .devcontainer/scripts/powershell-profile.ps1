# Docker Model Runner helper functions
function Invoke-ModelPull { docker model pull $args }
function Invoke-ModelRun { docker model run $args }
function Invoke-ModelList { docker model ls }

# Create aliases
New-Alias -Name model_pull -Value Invoke-ModelPull
New-Alias -Name model_run -Value Invoke-ModelRun
New-Alias -Name model_ls -Value Invoke-ModelList