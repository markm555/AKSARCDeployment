While (1)
{
   cls
   CMD.EXE /C .azure-kubectl\kubectl get pods -A -o wide
   Start-Sleep -Seconds 5
}
