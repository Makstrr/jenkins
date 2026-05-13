import pandas as pd
import numpy as np
from sklearn.datasets import fetch_california_housing


def download_and_prepare():
    housing = fetch_california_housing(as_frame=True)
    df = housing.frame  # pandas DataFrame
    print(f"Загружено {df.shape[0]} строк, {df.shape[1]} столбцов")

    if df.isnull().sum().sum() > 0:
        df = df.dropna()

    df = df[df['MedHouseVal'] <= 5.0]

    df.to_csv('california_housing_clean.csv', index=False)
    print("Датасет сохранён как california_housing_clean.csv")
    return df


if __name__ == "__main__":
    download_and_prepare()