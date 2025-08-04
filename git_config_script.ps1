# --- 인터랙티브 메뉴 함수 ---
function Show-InteractiveMenu {
    param(
        [string]$Title,
        [string[]]$Options,
        [string]$LastProfile
    )
    $selectedIndex = 0
    $esc = "$([char]27)" # ANSI 이스케이프 문자

    while ($true) {
        Clear-Host
        Write-Host ("=" * 55)
        Write-Host "             $Title" -ForegroundColor Cyan
        if ($LastProfile -ne "없음") {
            Write-Host " (최근 사용: $LastProfile)" -ForegroundColor DarkGray
        }
        Write-Host ("=" * 55)`n`

        for ($i = 0; $i -lt $Options.Length; $i++) {
            $optionText = $Options[$i]
            # '저장'이 포함된 메뉴에 아이콘 추가
            if ($optionText -like "*에 저장*") {
                $optionText = "💾 $optionText"
            }

            if ($i -eq $selectedIndex) {
                $displayText = "$esc[5m$optionText$esc[0m"
                Write-Host "  ▶ $displayText" -BackgroundColor White -ForegroundColor Black
            } else {
                Write-Host "    $optionText"
            }
        }

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            38 { if ($selectedIndex -gt 0) { $selectedIndex-- } } # UpArrow
            40 { if ($selectedIndex -lt $Options.Length - 1) { $selectedIndex++ } } # DownArrow
            13 { return $Options[$selectedIndex] } # Enter
            27 { return $null } # Escape
        }
    }
}

# --- 메인 애플리케이션 루프 ---
while ($true) {
    $lastProfileFile = ".last_profile"
    $lastAppliedProfile = "없음"
    if (Test-Path $lastProfileFile) {
        $lastAppliedProfile = Get-Content $lastProfileFile
    }

    # --- 동적 메인 메뉴 구성 ---
    $mainMenuOptions = [System.Collections.Generic.List[string]]@(
        "현재 설정 보기",
        "프로필 불러와 적용하기",
        "현재 설정을 새 프로필로 저장"
    )
    # 최근 사용 프로필이 있을 때만 '현재 프로필에 저장' 메뉴 추가
    if ($lastAppliedProfile -ne "없음") {
        $mainMenuOptions.Insert(2, "현재 프로필 '$lastAppliedProfile'에 저장")
    }
    $mainMenuOptions.AddRange(@(
        "직전 설정으로 복구",
        "Git 글로벌 설정 초기화",
        "종료"
    ))

    # 메뉴 표시 및 사용자 선택
    $rawChoice = Show-InteractiveMenu -Title "Git 프로필 관리자" -Options $mainMenuOptions -LastProfile $lastAppliedProfile
    # 아이콘 제거
    $choice = if ($rawChoice) { $rawChoice.Replace("💾 ", "") } else { $null }

    if (-not $choice -or $choice -eq "종료") { break }

    # --- 자동 백업 로직 ---
    $actionsThatChangeConfig = @(
        "프로필 불러와 적용하기",
        "직전 설정으로 복구",
        "Git 글로벌 설정 초기화"
    )
    if ($actionsThatChangeConfig -contains $choice) {
        $profilesDir = "profiles"
        if (-not (Test-Path $profilesDir)) { New-Item -ItemType Directory -Path $profilesDir | Out-Null }
        $backupContent = git config --global --list
        if ($backupContent) { Set-Content -Path "$profilesDir/backup.conf" -Value $backupContent }
    }

    $oldConfig = @{}
    (git config --list) | ForEach-Object { $parts = $_.Split('=', 2); $oldConfig[$parts[0]] = $parts[1] }
    
    Clear-Host
    switch ($choice) {
        "현재 설정 보기" {
            # ... (이전과 동일) ...
            Write-Host "`n======================================================="
            Write-Host "                현재 Git 설정 전체 목록"
            Write-Host "======================================================="
            if ($oldConfig.Count -eq 0) {
                Write-Host "`n표시할 설정이 없습니다." -ForegroundColor Yellow
            } else {
                foreach ($group in ($oldConfig.GetEnumerator() | Group-Object { ($_.Name.Split('.'))[0] } | Sort-Object Name)) {
                    Write-Host "`n [ $($group.Name) ]" -ForegroundColor Cyan
                    foreach ($item in $group.Group | Sort-Object Name) {
                        Write-Host "   $($item.Name) " -NoNewline -ForegroundColor Yellow
                        Write-Host "=" -NoNewline
                        Write-Host " $($item.Value)" -ForegroundColor White
                    }
                }
            }
            Write-Host "`n======================================================="
        }
        "프로필 불러와 적용하기" {
            # ... (이전과 동일) ...
            $profilesDir = "profiles"
            if (-not (Test-Path $profilesDir)) { New-Item -ItemType Directory -Path $profilesDir | Out-Null }
            $profileFiles = Get-ChildItem -Path $profilesDir -Filter "*.conf" | Where-Object { $_.Name -ne 'backup.conf' }
            if ($profileFiles.Count -eq 0) { Write-Host "❌ '$profilesDir' 폴더에 저장된 프로필 파일(.conf)이 없습니다." -ForegroundColor Red; break }
            $profileNames = $profileFiles.BaseName | Sort-Object
            $selectedProfileName = Show-InteractiveMenu -Title "적용할 프로필을 선택하세요 (취소: ESC)" -Options $profileNames
            if ($selectedProfileName) {
                $selectedFile = $profileFiles | Where-Object { $_.BaseName -eq $selectedProfileName }
                Write-Host "`n'$($selectedFile.BaseName)' 프로필을 적용합니다..."
                (Get-Content $selectedFile.FullName) | ForEach-Object {
                    if ($_ -match '(.+)=(.+)') { $key = $matches[1].Trim(); $value = $matches[2].Trim(); git config --global $key $value; Write-Host "  set: $key" }
                }
                Set-Content -Path $lastProfileFile -Value $selectedProfileName
                Write-Host "✅ 적용 완료." -ForegroundColor Green
            } else { Write-Host "`n프로필 적용을 취소했습니다." -ForegroundColor Yellow }
        }
        "현재 프로필 '$lastAppliedProfile'에 저장" {
            $profilesDir = "profiles"
            $profileToOverwriteFile = Join-Path -Path $profilesDir -ChildPath "$lastAppliedProfile.conf"

            if (-not (Test-Path $profileToOverwriteFile)) {
                Write-Host "❌ 덮어쓸 프로필 파일('$lastAppliedProfile.conf')을 찾을 수 없습니다." -ForegroundColor Red; break
            }
            
            # 파일 수정 전/후를 비교하기 위해 이전 내용 저장
            $oldProfileContent = Get-Content $profileToOverwriteFile
            $newProfileContent = git config --global --list

            if (-not $newProfileContent) {
                Write-Host "❌ 저장할 글로벌 설정이 없습니다." -ForegroundColor Red; break
            }

            # 파일 덮어쓰기
            Set-Content -Path $profileToOverwriteFile -Value $newProfileContent
            Write-Host "✅ '$lastAppliedProfile.conf' 프로필을 현재 설정으로 저장했습니다." -ForegroundColor Green

            # 프로필 파일의 변경 내역 표시
            $oldProfileData = @{}; $oldProfileContent | ForEach-Object { if ($_ -match '(.+)=(.+)') { $oldProfileData[$matches[1].Trim()] = $matches[2].Trim() } }
            $newProfileData = @{}; $newProfileContent | ForEach-Object { if ($_ -match '(.+)=(.+)') { $newProfileData[$matches[1].Trim()] = $matches[2].Trim() } }
            $allProfileKeys = ($oldProfileData.Keys + $newProfileData.Keys) | Sort-Object -Unique
            
            Write-Host "`n======================================================="; Write-Host "           프로필 파일 변경 내역"; Write-Host "======================================================="
            $profileChanges = 0
            foreach ($key in $allProfileKeys) {
                 $inOld = $oldProfileData.ContainsKey($key); $inNew = $newProfileData.ContainsKey($key)
                 if ($inOld -and $inNew -and ($oldProfileData[$key] -ne $newProfileData[$key])) { # Modified
                     Write-Host "   $key " -NoNewline -ForegroundColor Yellow; Write-Host "=" -NoNewline; Write-Host " $($newProfileData[$key])" -ForegroundColor Yellow; Write-Host " (원래 값: $($oldProfileData[$key]))" -ForegroundColor DarkGray
                     $profileChanges++
                 } elseif (!$inOld -and $inNew) { # Added
                     Write-Host "+  $key " -NoNewline -ForegroundColor Yellow; Write-Host "=" -NoNewline; Write-Host " $($newProfileData[$key])" -ForegroundColor Green
                     $profileChanges++
                 } elseif ($inOld -and !$inNew) { # Deleted
                     Write-Host "-  $key" -NoNewline -ForegroundColor Red; Write-Host "= $($oldProfileData[$key]) (삭제됨)" -ForegroundColor Red
                     $profileChanges++
                 }
            }
            if ($profileChanges -eq 0) { Write-Host "`n프로필 파일에 변경된 내용이 없습니다." -ForegroundColor Yellow }
            Write-Host "`n======================================================="
        }
        "현재 설정을 새 프로필로 저장" {
            # ... (이전과 동일) ...
            $profilesDir = "profiles"
            if (-not (Test-Path $profilesDir)) { New-Item -ItemType Directory -Path $profilesDir | Out-Null }
            Write-Host "`n현재 모든 글로벌 설정을 저장합니다..."
            $allGlobalConfig = git config --global --list
            if (-not $allGlobalConfig) { Write-Host "❌ 저장할 글로벌 설정이 없습니다." -ForegroundColor Red; break }
            $profileName = Read-Host "`n저장할 프로필의 파일 이름을 입력하세요 (미입력 시 자동 이름 생성)"
            if ([string]::IsNullOrWhiteSpace($profileName)) { $i = 1; while (Test-Path "$profilesDir/새 설정 $i.conf") { $i++ }; $profileName = "새 설정 $i" }
            $filePath = Join-Path -Path $profilesDir -ChildPath "$profileName.conf"
            Set-Content -Path $filePath -Value $allGlobalConfig
            Write-Host "✅ '$profileName.conf' 이름으로 모든 글로벌 설정을 '$profilesDir' 폴더에 저장했습니다." -ForegroundColor Green
            Write-Host "`n======================================================="
            Write-Host "            저장된 프로필: $($profileName).conf 내용"
            Write-Host "======================================================="
            Get-Content -Path $filePath | Write-Host
            Write-Host "======================================================="
        }
        "직전 설정으로 복구" {
            # ... (이전과 동일) ...
            $profilesDir = "profiles"
            $backupFile = "$profilesDir/backup.conf"
            if (-not (Test-Path $backupFile)) { Write-Host "❌ 복구할 백업 파일이 없습니다." -ForegroundColor Red; break }
            Write-Host "`n직전 설정('backup.conf')으로 복구합니다..."
            (Get-Content $backupFile) | ForEach-Object {
                if ($_ -match '(.+)=(.+)') { $key = $matches[1].Trim(); $value = $matches[2].Trim(); git config --global $key $value; Write-Host "  set: $key" }
            }
            Write-Host "✅ 복구 완료." -ForegroundColor Green
        }
        "Git 글로벌 설정 초기화" {
            # ... (이전과 동일) ...
            Write-Host "`nGit 글로벌 설정을 초기화합니다..."
            $globalConfigFile = git config --global --get-path
            if (Test-Path $globalConfigFile) { Clear-Content $globalConfigFile }
            Write-Host "✅ 모든 글로벌 설정을 초기화했습니다." -ForegroundColor Green
        }
    }

    # --- Git 설정 변경 내역 출력 ---
    $actionsThatShowGitDiff = @(
        "프로필 불러와 적용하기",
        "직전 설정으로 복구",
        "Git 글로벌 설정 초기화"
    )
    if ($actionsThatShowGitDiff -contains $choice) {
        # ... (이전과 동일) ...
        $newConfig = @{}; (git config --list) | ForEach-Object { $parts = $_.Split('=', 2); $newConfig[$parts[0]] = $parts[1] }
        $allItems = @(); $allKeys = ($oldConfig.Keys + $newConfig.Keys) | Sort-Object -Unique
        foreach ($key in $allKeys) {
            $item = [PSCustomObject]@{ Section = ($key.Split('.'))[0]; Key = $key; OldValue = $oldConfig[$key]; NewValue = $newConfig[$key]; Status = '' }
            $inOld = $oldConfig.ContainsKey($key); $inNew = $newConfig.ContainsKey($key)
            if ($inOld -and $inNew) { if ($item.OldValue -eq $item.NewValue) { $item.Status = 'Unchanged' } else { $item.Status = 'Modified' } }
            elseif ($inOld -and !$inNew) { $item.Status = 'Deleted' } else { $item.Status = 'Added' }
            $allItems += $item
        }
        Write-Host "`n======================================================="; Write-Host "           작업 완료 후, Git 설정 변경 내역"; Write-Host "======================================================="
        $changedItemsCount = ($allItems | Where-Object { $_.Status -ne 'Unchanged' }).Count
        if ($changedItemsCount -eq 0) { Write-Host "`n변경된 내용이 없습니다." -ForegroundColor Yellow }
        else {
            foreach ($group in ($allItems | Where-Object { $_.Status -ne 'Unchanged' } | Group-Object -Property Section | Sort-Object Name)) {
                Write-Host "`n [ $($group.Name) ]" -ForegroundColor Cyan
                foreach ($item in $group.Group) {
                    switch ($item.Status) {
                        'Added'    { Write-Host "+  $($item.Key) " -NoNewline -ForegroundColor Yellow; Write-Host "=" -NoNewline; Write-Host " $($item.NewValue)" -ForegroundColor Green }
                        'Modified' { Write-Host "   $($item.Key) " -NoNewline -ForegroundColor Yellow; Write-Host "=" -NoNewline; Write-Host " $($item.NewValue)" -ForegroundColor Yellow; Write-Host " (원래 값: $($item.OldValue))" -ForegroundColor DarkGray }
                        'Deleted'  { Write-Host "-  $($item.Key)" -NoNewline -ForegroundColor Red; Write-Host "= $($item.OldValue) (삭제됨)" -ForegroundColor Red }
                    }
                }
            }
        }
        Write-Host "`n======================================================="
    }
    
    if ($choice) { Read-Host "`n작업 내용을 확인했습니다. Enter를 누르면 메인 메뉴로 돌아갑니다." }
}