import csv
import random
import hashlib
import os

def generate_large_csv(file_path, size_gb, names):
    """
    Generates a large CSV file with random data.

    Args:
        file_path (str): The path to the output CSV file.
        size_gb (int): The desired file size in gigabytes.
        names (list): A list of names to choose from randomly.
    """
    target_size_bytes = size_gb * 1024**3
    headers = ['id', 'name', 'age']

    print(f"Starting to generate a {size_gb}GB CSV file at {file_path}...")
    print("This process will take a significant amount of time and disk space.")

    try:
        with open(file_path, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(headers)

            row_count = 0
            # Continuously write to the file until the target size is reached
            while os.path.getsize(file_path) < target_size_bytes:
                # Write in batches to improve efficiency by reducing the frequency of file size checks
                batch_size = 10000
                rows_to_write = []
                for _ in range(batch_size):
                    # Generate random data for each column
                    user_id = hashlib.sha256(str(random.getrandbits(256)).encode('utf-8')).hexdigest()
                    name = random.choice(names)
                    age = random.randint(18, 60)
                    rows_to_write.append([user_id, name, age])
                    row_count += 1

                writer.writerows(rows_to_write)

                # Provide progress updates periodically
                if row_count % 100000 == 0:
                    current_size_gb = os.path.getsize(file_path) / 1024**3
                    print(f"Generated {row_count} rows. Current file size: {current_size_gb:.2f}GB")

    except IOError as e:
        print(f"An error occurred while writing to the file: {e}")
        return
    except KeyboardInterrupt:
        print("\nProcess interrupted by user.")
        return

    final_size_gb = os.path.getsize(file_path) / 1024**3
    print("\n--------------------------------------------------")
    print(f"Successfully generated {file_path}.")
    print(f"Total rows generated: {row_count}")
    print(f"Final file size: {final_size_gb:.2f}GB")
    print("--------------------------------------------------")


if __name__ == '__main__':
    # A list of common English short first names for data generation
    first_names = [
        "Liam", "Noah", "Jack", "Levi", "Owen", "John", "Leo", "Luke", "Ezra", "Luca",
        "Alex", "Alan", "Ben", "Kyle", "Kurt", "Lou", "Matt", "Ryan", "Mia", "Elias",
        "Mila", "Nova", "Axel", "Leon", "Amara", "Finn", "Molly", "Brian", "Dante",
        "Rhys", "Thea", "Otis", "Rohan", "Anne", "Britt", "Brooks", "Cash", "Dane",
        "Eve", "Gem", "Huck", "Ivy", "Lael", "Mack", "Maeve", "Nell", "Onyx", "Pace",
        "Quinn", "Reed", "Scout", "Taft", "Ula", "Van", "Wade", "West"
    ]

    # Define the output file path and the desired size in gigabytes
    output_file_path = 'large_data.csv'
    desired_size_gb = 100

    generate_large_csv(output_file_path, desired_size_gb, first_names)
