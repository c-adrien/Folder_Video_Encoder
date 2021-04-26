# PowerShell script : encode all files in folder using ffmpeg

#========================================================================

# Get user inputs
function get-UserInputs {
    $crf = Read-Host 'Enter CRF value '
    $maxrate = Read-Host 'Enter maximum bitrate (kilobits) '

    Write-Host - Do nothing = 0
    Write-Host - Shutdown = 1
    $option= Read-Host 'Shutdown option '

    Write-Host -fore cyan  ======================== Processing FOLDER ==========================`n

    return $option, $crf, $maxrate 
}

# Check if user input is an integer
function checkInteger {
    param (
        $toCheck
    )

    try {
        [int]$toCheck
        return 0
    }
    catch {
        return 1
    } 
}

# Encoding function & error log
function encode {
    param (
        $filePath,
        $arrayParameters
    )

    $filename = Split-Path -leaf $filePath
    Write-Host 'Processing' $filename `n

    $CRF = $arrayParameters[1]
    $maxrate = -join($arrayParameters[2], 'k')
    $bufsize = -join($arrayParameters[3], 'k')

    # ffmpeg command
    ffmpeg -hide_banner -loglevel error -stats -n -i $filename -map 0 -c copy -c:v:0 libx265 -pix_fmt yuv420p10le `
    -x265-params profile=main10 -level:v 4.0 -crf $CRF `
    -maxrate $maxrate -bufsize $bufsize "./encode/ $filename [ENCODED x265 CRF $CRF].mkv"

    # Redirect errors to encoding_errors.log
    if($LASTEXITCODE -ne 0) {
        Add-Content encoding_errors.log $filename
        Write-Host 'Failed' $filename `n  
    }
    else {
        Write-Host 'Completed' $filename `n
    }
}

function write-banner {
    Write-Host -fore cyan ________________________ Folder encoder x265 ________________________
    $host.ui.RawUI.WindowTitle = 'Folder encoder x265'
}

function InputErrorExit {
    Write-Host -fore cyan  `n======================== Processing ERROR ===========================
    $host.ui.RawUI.WindowTitle = 'Folder encoder x265 - COMPLETED'
    Write-Host -fore red '> Usage : all inputs should be integers'`n
    Read-Host -Prompt 'Press Enter to continue...'
}

function EncodingErrorExit {
    Write-Host -fore cyan  `n======================== Processing COMPLETED =======================`n
    $host.ui.RawUI.WindowTitle = 'Folder encoder x265 - COMPLETED'
    Write-Host -fore red '> Completed with encoding errors'
    
    $logFile = 'encoding_errors.log'
    Get-Content $logFile

    Read-Host -Prompt 'Press Enter to continue...'
}

function NormalExit {
    Write-Host -fore cyan  `n======================== Processing COMPLETED =======================`n
    $host.ui.RawUI.WindowTitle = 'Folder encoder x265 - COMPLETED'
    Read-Host -Prompt 'Press Enter to continue...'
}

#========================================================================

write-banner

$arrayParameters = get-UserInputs

# Check user inputs
for ($i = 0; $i -lt $arrayParameters.Count; $i++) {
    $storeExit = 0
    $isCorrect = checkInteger -toCheck $arrayParameters[$i]

    if($isCorrect -eq 1){
        Write-Host -fore red 'Incorrect input : ' $arrayParameters[$i]
        $storeExit = 1
    }
}

# Exit if >0 wrong input
if ($storeExit -eq 1) {
    InputErrorExit
}

else {
    # Calculate bufsize
    $bufsize = [int]$arrayParameters[2] * 2
    $arrayParameters += $bufsize

    # Delete former log file
    $logFile = "encoding_errors.log"
    if (Test-Path $logFile) {
        Remove-Item $logFile
    }

    # Output folder
    $path = "encode"
    if (!(test-path $path)) {
        New-Item -ItemType Directory -Force -Path $path | out-null
    }
    
    # Get current directory
    $directory = $MyInvocation.MyCommand.Path
    $directory = Split-Path -Path $directory
    
    # Grab & encode all video files
    Get-ChildItem $directory\* -Include *.mkv, *.mp4, *.avi, *.mov, *.webm, *.ts |
    Foreach-Object {
        encode -filePath $_ -arrayParameters $arrayParameters
    }

    # If shutdown option selected
    if ($arrayParameters[0] -eq 1){
        Stop-Computer
    }

    # Exit mode
    if (Test-Path $logFile) {
        EncodingErrorExit
    }
    else {
        NormalExit
    }
}

