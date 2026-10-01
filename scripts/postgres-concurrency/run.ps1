param([switch]$BeforeFix,[string]$PostgreSqlBin='C:\Program Files\PostgreSQL\18\bin')
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$psql=Join-Path $PostgreSqlBin 'psql.exe'
$initdb=Join-Path $PostgreSqlBin 'initdb.exe'
$pgCtl=Join-Path $PostgreSqlBin 'pg_ctl.exe'
foreach($exe in @($psql,$initdb,$pgCtl)){if(-not(Test-Path -LiteralPath $exe)){throw "Missing $exe"}}
$port=Get-Random -Minimum 55420 -Maximum 55880
$clusterRoot=Join-Path $env:TEMP ('perpus-concurrency-'+[guid]::NewGuid().ToString('N'))
$dataDir=Join-Path $clusterRoot 'data'
$logDir=Join-Path $clusterRoot 'logs'
New-Item -ItemType Directory -Path $clusterRoot,$logDir -Force|Out-Null
$serverLog=Join-Path $logDir 'postgres.log'
$env:PGHOST='127.0.0.1';$env:PGPORT=[string]$port;$env:PGUSER='postgres';$env:PGDATABASE='postgres';$env:PGPASSWORD='';$env:PGCONNECT_TIMEOUT='3'
function Invoke-File([string]$file,[switch]$AllowFailure){
  & $psql -X -q -v ON_ERROR_STOP=1 -f $file
  $code=$LASTEXITCODE
  if($code -ne 0 -and -not $AllowFailure){throw "psql failed ($code): $file"}
  return $code
}
function Scalar([string]$sql){
  $v=& $psql -X -q -A -t -v ON_ERROR_STOP=1 -c $sql
  if($LASTEXITCODE -ne 0){throw 'PostgreSQL scalar query failed'}
  return (($v|Out-String).Trim())
}
function Start-File([string]$file,[string]$name){
  $out=Join-Path $logDir ($name+'.out');$err=Join-Path $logDir ($name+'.err')
  $arguments='-X -q -v ON_ERROR_STOP=1 -f "'+$file+'"'
  return Start-Process -FilePath $psql -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
}
function Wait-File($proc,[string]$name){
  if(-not $proc.WaitForExit(20000)){try{$proc.Kill()}catch{};throw "$name timed out (possible deadlock)"}
  $proc.Refresh()
  return [int]$proc.ExitCode
}
$started=$false
try{
  & $initdb -D $dataDir -U postgres -A trust --no-locale -E UTF8
  if($LASTEXITCODE -ne 0){throw 'initdb failed'}
  & $pgCtl -D $dataDir -l $serverLog -o "-h 127.0.0.1 -p $port" -w start
  if($LASTEXITCODE -ne 0){throw 'pg_ctl start failed'}
  $started=$true
  Invoke-File (Join-Path $PSScriptRoot 'bootstrap.sql')|Out-Null
  $migrationDir=Join-Path $repoRoot 'supabase\migrations'
  foreach($migration in Get-ChildItem -LiteralPath $migrationDir -Filter '*.sql'|Sort-Object Name){
    if($BeforeFix -and $migration.Name -eq '202609300003_inventory_lock_protocol.sql'){continue}
    Write-Output ('MIGRATION '+$migration.Name)
    Invoke-File $migration.FullName|Out-Null
  }
  Invoke-File (Join-Path $PSScriptRoot 'fixture.sql')|Out-Null

  Write-Output 'CASE approval/archive'
  $approval=Start-File (Join-Path $PSScriptRoot 'approve_archive.sql') 'approval_archive'
  Start-Sleep -Milliseconds 250
  $archiveExit=Invoke-File (Join-Path $PSScriptRoot 'archive.sql') -AllowFailure
  $approvalExit=Wait-File $approval 'approval/archive'
  $race=Scalar "select c.status||'|'||(c.archived_at is not null)::text||'|'||(b.archived_at is not null)::text||'|'||(select count(*) from public.loan_items li where li.copy_id=c.id and li.returned_at is null and li.resolved_at is null) from public.book_copies c join public.books b on b.id=c.book_id where c.id='40000000-0000-4000-8000-000000000101'"
  if($approvalExit -ne 0){throw 'Approval/archive approval did not commit'}
  if($race -ne 'borrowed|false|false|1'){throw "Approval/archive invariant failed: $race"}
  if($archiveExit -eq 0){throw "Approval/archive bug reproduced; archive succeeded with state $race"}
  Write-Output 'PASS approval/archive: active loan remains unarchived and archive rejects'

  Write-Output 'CASE two approvals, same copy'
  $a=Start-File (Join-Path $PSScriptRoot 'approve_a.sql') 'approval_a'
  Start-Sleep -Milliseconds 250
  $b=Start-File (Join-Path $PSScriptRoot 'approve_b.sql') 'approval_b'
  $ea=Wait-File $a 'approval A';$eb=Wait-File $b 'approval B'
  $same=Scalar "select (select count(*) from public.loans l join public.loan_items li on li.loan_id=l.id where li.copy_id='40000000-0000-4000-8000-000000000102' and li.returned_at is null and li.resolved_at is null)::text||'|'||(select count(*) from public.loan_requests where idempotency_key in ('50000000-0000-4000-8000-000000000103','50000000-0000-4000-8000-000000000105') and status='approved')::text||'|'||(select status from public.book_copies where id='40000000-0000-4000-8000-000000000102')"
  if($same -ne '1|1|borrowed'){throw "Same-copy approval state failed: $same"}
  if($ea -eq 124 -or $eb -eq 124){throw 'A same-copy approval did not finish before the deadlock timeout'}
  Write-Output 'PASS same-copy approvals: one winner, no duplicate loan'

  Write-Output 'CASE reversed multi-item input order'
  $ma=Start-File (Join-Path $PSScriptRoot 'approve_multi_a.sql') 'multi_a'
  Start-Sleep -Milliseconds 250
  $mb=Start-File (Join-Path $PSScriptRoot 'approve_multi_b.sql') 'multi_b'
  $ema=Wait-File $ma 'multi approval A';$emb=Wait-File $mb 'multi approval B'
  $multi=Scalar "select (select count(*) from public.loan_items li join public.loans l on l.id=li.loan_id where li.copy_id in ('40000000-0000-4000-8000-000000000103','40000000-0000-4000-8000-000000000104') and li.returned_at is null and li.resolved_at is null)::text||'|'||(select count(*) from public.loan_requests where idempotency_key in ('50000000-0000-4000-8000-000000000104','50000000-0000-4000-8000-000000000106') and status='approved')::text||'|'||(select string_agg(status,',' order by id) from public.book_copies where id in ('40000000-0000-4000-8000-000000000103','40000000-0000-4000-8000-000000000104'))"
  if($multi -ne '2|1|borrowed,borrowed'){throw "Reversed multi-item state failed: $multi"}
  if($ema -eq 124 -or $emb -eq 124){throw 'A multi-item approval did not finish before the deadlock timeout'}
  Write-Output 'PASS reversed multi-item approvals: atomic winner, no deadlock'
  Write-Output 'POSTGRES_CONCURRENCY_RESULT=PASS'
}catch{
  Write-Output ('POSTGRES_CONCURRENCY_RESULT=FAIL: '+$_.Exception.Message)
  if(Test-Path -LiteralPath $logDir){Get-ChildItem -LiteralPath $logDir -Filter '*.err'|ForEach-Object{Write-Output ('--- '+$_.Name);Get-Content -LiteralPath $_.FullName}}
  if(Test-Path -LiteralPath $serverLog){Get-Content -LiteralPath $serverLog -Tail 25}
  throw
}finally{
  if($started){& $pgCtl -D $dataDir -m fast -w stop|Out-Null}
  $tempRoot=[System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
  $target=[System.IO.Path]::GetFullPath($clusterRoot)
  if($target.StartsWith($tempRoot,[System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $target).StartsWith('perpus-concurrency-')){
    Remove-Item -LiteralPath $target -Recurse -Force
  }
}
