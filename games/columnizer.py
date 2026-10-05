import pandas as pd
import os

def save_unique_per_column(input_csv, output_folder):
    df = pd.read_csv(input_csv).fillna(0)
    df = df.apply(lambda x: x.str.strip().str.replace(r'\s+', '', regex=True) if x.dtype == "object" else x)
    os.makedirs(output_folder, exist_ok=True)
    non_numeric_cols = ["Material","Country","Stage"]

    for col in non_numeric_cols:
        df[col] = df[col].astype(str).str.replace('.', '', regex=False)
#        df[col] = df[col].str.replace(' ', '')
        unique_vals = df[col].dropna().unique()
        #unique_vals = unique_vals.str.replace(' ', '')
        out_df = pd.DataFrame(unique_vals)
        filename = os.path.join(output_folder, f"{col}.csv")
        out_df.to_csv(filename, index=False, header=False)
        print(f"saved {filename}")
        
save_unique_per_column("/Users/max/Documents/GitHub/EBGN645_Fall25/games/production.csv","/Users/max/Documents/GitHub/EBGN645_Fall25/games/")