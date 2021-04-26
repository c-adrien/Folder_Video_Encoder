# PowerShell script : encode all files in folder using ffmpeg

#========================================================================

# Get user inputs
function get-UserInputs {
    Write-Host - x264 = 0
    Write-Host - x265 = 1
    Write-Host - Both = 2
    $codec = Read-Host 'Select codec '
    $crf = Read-Host 'Enter CRF value '
    $maxrate = Read-Host 'Enter maximum bitrate (kilobits) '

    Write-Host - Do nothing = 0
    Write-Host - Shutdown = 1
    $shutdown_option= Read-Host 'Shutdown option '

    Write-Host -fore cyan  ======================== Processing FOLDER ==========================`n

    return $shutdown_option, $crf, $maxrate, $codec
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

# x264 encoding function & error log
function encode_x264 {
    param (
        $filePath,
        $arrayParameters
    )

    $filename = Split-Path -leaf $filePath
    Write-Host 'Processing' $filename `n

    $CRF = $arrayParameters[1]
    $maxrate = -join($arrayParameters[2], 'k')
    $bufsize = -join($arrayParameters[4], 'k')

    # ffmpeg command
    ffmpeg -hide_banner -loglevel error -stats -n -i $filename -map 0 -c copy -c:v:0 libx264 -tune film -preset slow -profile:v high `
    -level:v 4.1 -crf $CRF -maxrate $maxrate -bufsize $bufsize -trellis 1 -x264-params ref=3:bframes=3:keyint=250:min-keyint=25:aq-mode=1:qcomp=0.6:no-dct-decimate=1:8x8dct=1:deblock=-1\\-1 `
     -bsf:v 'filter_units=remove_types=6' "./encode/ $filename [ENCODED x264 CRF $CRF].mkv"

    # Redirect errors to encoding_errors.log
    if($LASTEXITCODE -ne 0) {
        Add-Content encoding_errors.log $filename
        Write-Host 'Failed' $filename `n  
    }
    else {
        Write-Host 'Completed' $filename `n
    }
}

# x265 encoding function & error log
function encode_x265 {
    param (
        $filePath,
        $arrayParameters
    )

    $filename = Split-Path -leaf $filePath
    Write-Host 'Processing' $filename `n

    $CRF = $arrayParameters[1]
    $maxrate = -join($arrayParameters[2], 'k')
    $bufsize = -join($arrayParameters[4], 'k')

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
    Write-Host -fore red '> Incorrect inputs'`n
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
# Array = $shutdown_option, $crf, $maxrate, $codec

# Check user inputs
for ($i = 0; $i -lt $arrayParameters.Count; $i++) {
    $storeExit = 0
    $isCorrect = checkInteger -toCheck $arrayParameters[$i]

    if($isCorrect -eq 1){
        Write-Host -fore red 'Incorrect input : ' $arrayParameters[$i]
        $storeExit = 1
    }
}

try {
    # If codec option != 0,  1 or 2
    if([int]$arrayParameters[3] -lt 0 -or [int]$arrayParameters[3] -gt 2){
        Write-Host -fore red 'ValueError : codec'`n 
        $storeExit = 1
    }
}
catch{
    $storeExit = 1
}

# Exit if >0 wrong input
if ($storeExit -eq 1) {
    InputErrorExit
}


else {
    # Calculate bufsize
    $bufsize = [int]$arrayParameters[2] * 2

    # Array = $shutdown_option, $crf, $maxrate, $codec, $bufsize
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

        if ([int]$arrayParameters[3] -eq 0 -or [int]$arrayParameters[3] -eq 2) {
            encode_x264 -filePath $_ -arrayParameters $arrayParameters
        }
        if ([int]$arrayParameters[3] -eq 1 -or [int]$arrayParameters[3] -eq 2) {
            encode_x265 -filePath $_ -arrayParameters $arrayParameters
        }
        
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
