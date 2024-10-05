param (
    [string]$inputFolder = $PSScriptRoot,  # Default to the script's calling directory if not specified
    [string]$outputFolder = ""             # Default to the input folder if not specified
)
function Get-ProcessUsingFile {
    param (
        [string]$filePath
    )

    $handleOutput = & ".\handle.exe" $filePath 2>&1
    $processInfo = $handleOutput | Select-String -Pattern "pid: (\d+)" -AllMatches

    if ($processInfo) {
        $processIds = $processInfo.Matches | ForEach-Object { $_.Groups[1].Value }
        $processNames = $processIds | ForEach-Object { (Get-Process -Id $_).Name }
        return [PSCustomObject]@{
            ProcessIds = $processIds
            ProcessNames = $processNames -join ", "
        }
    } else {
        return $null
    }
}

function OpenFileWithPrompt {
    param (
        [string]$filePath,
        [System.IO.FileMode]$mode,
        [System.IO.FileAccess]$access
    )

    while ($true) {
        try {
            Write-Output "Attempting to open file: $filePath"
            $fileStream = [System.IO.File]::Open($filePath, $mode, $access)
            Write-Output "File opened successfully: $filePath"
            return $fileStream
        } catch [System.IO.IOException] {
            Write-Output "IO Exception: $($_.Exception.Message)"

            if ($_.Exception.Message -match "being used by another process") {
		Write-Output "File is in used..."
                $processInfo = Get-ProcessUsingFile -filePath $filePath
                if ($processInfo) {
                    Write-Output "File is in use by: $($processInfo.ProcessNames)."
                    $userChoice = Read-Host "Do you want to retry (r) or force close the process (f)?"
                    if ($userChoice -eq 'f') {
                        $processInfo.ProcessIds | ForEach-Object { Stop-Process -Id $_ -Force }
                        Write-Output "Processes forcefully closed. Retrying..."
                    } else {
                        Write-Output "Retrying..."
                    }
                } else {
                    Write-Output "No process found using the file. Retrying..."
                }
            } else {
                throw $_
            }
        }
    }
}


##########
# Ensure input folder exists
if (-Not (Test-Path -Path $inputFolder)) {
    throw "Input folder does not exist: $inputFolder"
}

# Use input folder as output folder if output folder is not specified
if ([string]::IsNullOrEmpty($outputFolder)) {
    $outputFolder = $inputFolder
}

# Ensure output folder exists
if (-Not (Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder
}

# Get all _xxx.bin files in the input folder
$inputFiles = Get-ChildItem -Path $inputFolder -Filter "*_*.split" -File
Write-Output $inputFiles
Write-Output ""

# Generate output file name based on input file names
$outputFileName = ($inputFiles[0].Name -replace '_[a-z]+\.split','')
$outputFilePath = Join-Path -Path $outputFolder -ChildPath $outputFileName

Write-Output "OUT: $outputFilePath"

# Check if the output file already exists
if (Test-Path -Path $outputFilePath) {
    while ($true) {
        $userChoice = Read-Host "Output file already exists. Do you want to replace it? (y/n)"
        if ($userChoice -eq 'y') {
            break
        } elseif ($userChoice -eq 'n') {
            throw "Operation cancelled by user."
        } else {
            Write-Output "Invalid input. Please enter 'y' to replace or 'n' to cancel."
        }
    }
}

# Open the output file as a FileStream
$outputStream = [System.IO.File]::OpenWrite($outputFilePath)

try {
    foreach ($file in $inputFiles) {
        Write-Output "Mergin file: $($file.FullName)"
        # Open each input file as a FileStream
        $inputStream =  [System.IO.File]::OpenRead($file.FullName)

        try {
            $buffer = New-Object byte[] 4096  # Buffer for reading data
            while ($true) {
                # Read from the input stream
                $readCount = $inputStream.Read($buffer, 0, $buffer.Length)

                
                if ($readCount -eq 0) {
                    # End of file reached
                    break
                }

                # Write to the output stream
                $outputStream.Write($buffer, 0, $readCount)
            }
        } finally {
            # Ensure the input stream is closed
            $inputStream.Close()
        }
    }
} finally {
    # Ensure the output stream is closed
    $outputStream.Close()
}
