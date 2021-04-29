# PowerShell script : 

<#
.SYNOPSIS
    Encode all video files in folder using ffmpeg
.EXAMPLE
    Execute the script
.INPUTS
    *.mkv, *.mp4, *.avi, *.mov, *.webm, *.ts
.OUTPUTS
    Encoded video files in "encode" subfolder
.NOTES
    Requires : ffmpeg
#>

using namespace System.Management.Automation.Host

#========================================================================

# Get user inputs
function get-UserInputs {

    # Choice Prompt codec
    $x264 = [ChoiceDescription]::new('x264', 'mainstream codec x264')
    $x265 = [ChoiceDescription]::new('x265', 'for better compression')
    $both = [ChoiceDescription]::new('Both', '')
    $options = [ChoiceDescription[]]($x264, $x265, $both)
    $title1 = 'Codec Selection'
    $message1 = '=> Select your video codec'
    $codec = $host.ui.PromptForChoice($title1, $message1, $options, 0)

    $crf = Read-Host 'Enter CRF value '
    $maxrate = Read-Host 'Enter maximum bitrate (kilobits) '


    # Choice Prompt shutdown option
    $no_shutdown = [ChoiceDescription]::new('Do not shutdown', 'Do not shutdown when completed')
    $shutdown = [ChoiceDescription]::new('Shutdown', 'Shutdown when completed')
    $options = [ChoiceDescription[]]($no_shutdown, $shutdown)
    $title2 = 'Shutdown option'
    $message2 = '=> When completed...'
    $shutdown_option = $host.ui.PromptForChoice($title2, $message2, $options, 0)

    Write-Host -fore cyan  ======================== Processing FOLDER ==========================`n

    return $shutdown_option, $codec, $crf, $maxrate
}

# x264 encoding function & error log
function encode_x264 {
    param (
        $filePath,
        $arrayParameters
    )

    $filename = Split-Path -leaf $filePath
    Write-Host 'Processing' $filename `n

    $CRF = $arrayParameters[$crf_index]
    $maxrate = $arrayParameters[$maxrate_index]
    $bufsize = $arrayParameters[$bufsize_index]

    # ffmpeg command
    ffmpeg -hide_banner -loglevel error -stats -n -i $filename -map 0 -c copy -c:v:0 libx264 -tune film -preset slow -profile:v high `
    -level:v 4.1 -crf $CRF -maxrate $maxrate -bufsize $bufsize -trellis 1 -x264-params `
    ref=3:bframes=3:keyint=250:min-keyint=25:aq-mode=1:qcomp=0.6:no-dct-decimate=1:8x8dct=1:deblock=-1\\-1 `
     -bsf:v 'filter_units=remove_types=6' "./encode/ $filename [ENCODED x264 CRF $CRF].mkv"

    # Redirect errors to encoding_errors.log
    if($LASTEXITCODE -ne 0) {
        Add-Content encoding_errors.log "x264 CRF $CRF : $filename"
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

    $CRF = $arrayParameters[$crf_index]
    $maxrate = $arrayParameters[$maxrate_index]
    $bufsize = $arrayParameters[$bufsize_index]

    # ffmpeg command
    ffmpeg -hide_banner -loglevel error -stats -n -i $filename -map 0 -c copy -c:v:0 libx265 -pix_fmt yuv420p10le `
    -x265-params profile=main10 -level:v 4.0 -crf $CRF `
    -maxrate $maxrate -bufsize $bufsize "./encode/ $filename [ENCODED x265 CRF $CRF].mkv"

    # Redirect errors to encoding_errors.log
    if($LASTEXITCODE -ne 0) {
        Add-Content encoding_errors.log "x265 CRF $CRF : $filename"
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
# Array = $shutdown_option, $codec, $crf, $maxrate

$shutdown_option_index = 0
$codec_index = 1
$crf_index = 2
$maxrate_index = 3

# Check user inputs
for ($i = 0; $i -lt $arrayParameters.Count; $i++) {
    $storeExit = 0

    try {
        $null = [int]$arrayParameters[$i]
    }
    catch {
        Write-Host -fore red 'Incorrect input : ' $arrayParameters[$i]
        $storeExit++;
    }
}

# Exit if >0 wrong input
if ($storeExit -ne 0) {
    InputErrorExit
}

else {
    # Calculate bufsize
    $bufsize = [int]$arrayParameters[$maxrate_index] * 2

    # Array = $shutdown_option, $codec, $crf, $maxrate, $bufsize
    $arrayParameters += $bufsize
    $bufsize_index = 4

    # ffmpeg bitrate formatting 
    $arrayParameters[$maxrate_index] = -join($arrayParameters[$maxrate_index], 'k')
    $arrayParameters[$bufsize_index] = -join($arrayParameters[$bufsize_index], 'k')    

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

        $filepath =  $_

        switch ([int]$arrayParameters[$codec_index]) {
            
            0 { encode_x264 -filePath $filepath -arrayParameters $arrayParameters }

            1 { encode_x265 -filePath $filepath -arrayParameters $arrayParameters }

            2 { encode_x264 -filePath $filepath -arrayParameters $arrayParameters
                encode_x265 -filePath $filepath -arrayParameters $arrayParameters }
        }
    }

    # If shutdown option selected
    if ($arrayParameters[$shutdown_option_index] -eq 1){
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

