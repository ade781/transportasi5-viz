import pandas as pd

# Read the original file
df = pd.read_csv('data_halte.csv')

# Select only the required columns
df_clean = df[['tapInStopsName', 'latitude',
               'longitude', 'total_penumpang_bulan']]

# Drop duplicates based on tapInStopsName, keeping the first occurrence
df_unique = df_clean.drop_duplicates(subset=['tapInStopsName'], keep='first')

# Reset index
df_unique = df_unique.reset_index(drop=True)

# Save to new file
df_unique.to_csv('halte_unik.csv', index=False)

print(f"Total original records: {len(df)}")
print(f"Total unique halte: {len(df_unique)}")
print("\nFirst 10 rows:")
print(df_unique.head(10))
print("\nFile saved as: halte_unik.csv")
