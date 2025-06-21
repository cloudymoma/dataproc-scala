#!/bin/bash

# Function to calculate 80% of available system memory
calculate_memory() {
  # Get available memory in kilobytes
  AVAILABLE_MEM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

  # Check if memory calculation succeeded
  if [ -z "$AVAILABLE_MEM_KB" ]; then
    echo "4g"
    return
  fi

  # Calculate 80% of available memory in kilobytes
  XMX_KB=$(( AVAILABLE_MEM_KB * 80 / 100 ))

  # Convert kilobytes to megabytes (Java expects -Xmx in megabytes)
  XMX_MB=$(( XMX_KB / 1024 ))

  # Return memory value in megabytes
  echo "${XMX_MB}m"
}

# Function to calculate the number of CPU cores
calculate_threads() {
  # Get the number of CPU cores
  CPU_CORES=$(nproc)

  # Check if core calculation succeeded
  if [ -z "$CPU_CORES" ]; then
    echo "4"
    return
  fi

  # Return the number of CPU cores
  echo "${CPU_CORES}"
}

# Default values
XMX=$(calculate_memory)  # Default memory is 80% of available system memory or 4g on failure
if [ "$XMX" == "m" ]; then
  XMX="4g"  # Fall back to 4g if calculation fails
fi

THREADS=$(calculate_threads)  # Default threads is the number of CPU cores or 4 on failure
if [ "$THREADS" == "" ]; then
  THREADS="4"  # Fall back to 4 if calculation fails
fi

FILE_PATH=""
KEY_PATH=""
OUTPUT_PATH="./output"  # Default output path is current directory/output
VERSION="1.2.1"  # Default version, now configurable
JAR_NAME="dataproc-perfboost-qualification-${VERSION}.jar"
JAR_URL="https://storage.googleapis.com/qualification-tool/${JAR_NAME}"

# Parse command-line arguments
while getopts "x:f:k:o:t:v:" opt; do
  case ${opt} in
    x ) XMX=$OPTARG
      ;;
    f ) FILE_PATH=$OPTARG
      ;;
    k ) KEY_PATH=$OPTARG
      ;;
    o ) OUTPUT_PATH=$OPTARG
      ;;
    t ) THREADS=$OPTARG
      ;;
    v ) VERSION=$OPTARG
        JAR_NAME="dataproc-perfboost-qualification-${VERSION}.jar"
        JAR_URL="https://storage.googleapis.com/qualification-tool/${JAR_NAME}"
      ;;
    \? ) echo "Usage: cmd [-x Xmx] [-f file_path] [-k key_path] [-o output_path] [-t threads] [-v version]"
      exit 1
      ;;
  esac
done

# Check if file path is provided
if [ -z "$FILE_PATH" ]; then
  echo "Error: File path (-f) is required."
  echo "Usage: cmd [-x Xmx] [-f file_path] [-k key_path] [-o output_path] [-t threads] [-v version]"
  exit 1
fi

# Create the output path if it doesn't exist
if [ ! -d "$OUTPUT_PATH" ]; then
  echo "Output path does not exist. Creating $OUTPUT_PATH..."
  mkdir -p "$OUTPUT_PATH"
  if [ $? -ne 0 ]; then
    echo "Failed to create output path $OUTPUT_PATH. Exiting."
    exit 1
  fi
fi

# Check if the JAR file exists; if not, download it
if [ ! -f "qualification-tool/${JAR_NAME}" ]; then
  echo "JAR file not found. Downloading ${JAR_NAME}..."
  mkdir -p qualification-tool
  wget -O "qualification-tool/${JAR_NAME}" ${JAR_URL}
  if [ $? -ne 0 ]; then
    echo "Failed to download ${JAR_NAME}. Exiting."
    exit 1
  fi
fi

echo "Using memory ${XMX}"
echo "Using cores ${THREADS}"

# Build the command
CMD="java -Xmx${XMX} -Djava.security.manager=allow -jar qualification-tool/${JAR_NAME} -f ${FILE_PATH} -o ${OUTPUT_PATH}"
if [ -n "$KEY_PATH" ]; then
  CMD+=" -k ${KEY_PATH}"
fi
CMD+=" -t ${THREADS}"

# Run the command and suppress standard error
$CMD 2>/dev/null
