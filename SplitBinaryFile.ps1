param (
    [string]$inputFile,           # Path to the input binary file
    [string]$outputFilePrefix = "", # Prefix for the output files
    [int]$maxFileLength = 1024000000, # Maximum length in bytes for an output file
    [int]$suffixLength = 1        # Length of the incrementing suffix
)

# Ensure the output folder exists
$outputFolder = Split-Path -Path $inputFile -Parent
if (-Not (Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder
}

# Open the input file as a FileStream
$inputStream = [System.IO.File]::OpenRead($inputFile)
$fileCount = 0
$fileSuffix = 'a' * $suffixLength  # Start with 'a' repeated suffixLength times

function Increment-Suffix {
    param (
        [string]$suffix
    )
    $charArray = $suffix.ToCharArray()
    for ($i = $charArray.Length - 1; $i -ge 0; $i--) {
        if ($charArray[$i] -eq [char]'z') {
            $charArray[$i] = ([int][char]$charArray[$i]+1)
            if ($i -eq 0) {
                $charArray = ,([char]'a') + $charArray
            }
        } else {
            $charArray[$i] = ([int][char]$charArray[$i]+1)
            break
        }
    }
    return -join $charArray
}

try {
    while ($true) {
        # Determine the output file prefix
        $prefix = if ($outputFilePrefix) { $outputFilePrefix } else { [System.IO.Path]::GetFileName($inputFile) }

        # Create the output file name
        $outputFile = Join-Path -Path $outputFolder -ChildPath ($prefix + "_" + $fileSuffix + ".split")

	    # Check if the output file already exists
        if (Test-Path -Path $outputFile) {
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
        
        # Create a new FileStream for the output file
        $outputStream = [System.IO.File]::OpenWrite($outputFile)

        try {
            $bytesRead = 0
            $buffer = New-Object byte[] 4096  # Buffer for reading data
            while ($bytesRead -lt $maxFileLength) {
                # Read from the input stream
                $readCount = $inputStream.Read($buffer, 0, [Math]::Min($buffer.Length, $maxFileLength - $bytesRead))
                
                if ($readCount -eq 0) {
                    # End of file reached
                    break
                }

                # Write to the output stream
                $outputStream.Write($buffer, 0, $readCount)
                $bytesRead += $readCount
            }
		    Write-OutPut "$outputFile"

            # Check if we wrote any bytes
            if ($bytesRead -eq 0 -or $readCount -eq 0) {
                break  # No more data to read
            }

            # Prepare for the next file
            $fileCount++
            # Increase the file suffix alphabetically
            $fileSuffix = Increment-Suffix $fileSuffix
        } finally {
            # Ensure the output stream is closed
            $outputStream.Close()
        }
    }
} finally {
    # Ensure the input stream is closed
    $inputStream.Close()
}
