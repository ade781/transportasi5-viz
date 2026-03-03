import pandas as pd

# Read the original file
df = pd.read_csv('data_halte.csv')

# Count occurrences of each tapInStopsName
halte_counts = df['tapInStopsName'].value_counts()

# Total records and unique halte
total_records = len(df)
unique_halte = len(halte_counts)  # Number of unique halte names
total_duplicates = total_records - unique_halte

# Halte dengan duplikat terbanyak
halte_with_dupes = halte_counts[halte_counts > 1].sort_values(ascending=False)

print(f"📊 ANALISIS DUPLIKASI HALTE")
print(f"{'='*60}")
print(f"Total records (all corridors):   {total_records:,}")
print(f"Unique halte:                    {unique_halte:,}")
print(f"Total duplicate records:         {total_duplicates:,}")
print(
    f"Duplicate rate:                  {(total_duplicates/total_records)*100:.1f}%")
print(f"\n🔴 TOP 20 HALTE DENGAN DUPLIKAT TERBANYAK:")
print(f"{'='*60}")
for halte, count in halte_with_dupes.head(20).items():
    print(f"{halte:40s} | {count:3d} occurrences ({count-1} duplicates)")

print(f"\n📈 DISTRIBUSI:")
print(f"{'='*60}")
print(
    f"Halte unik (no duplicates):      {(halte_counts == 1).sum():,} ({(halte_counts == 1).sum()/len(halte_counts)*100:.1f}%)")
print(
    f"Halte dengan 2-5 occurrences:    {((halte_counts >= 2) & (halte_counts <= 5)).sum():,}")
print(
    f"Halte dengan 6-10 occurrences:   {((halte_counts >= 6) & (halte_counts <= 10)).sum():,}")
print(f"Halte dengan >10 occurrences:    {(halte_counts > 10).sum():,}")
