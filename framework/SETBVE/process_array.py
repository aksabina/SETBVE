from sklearn.preprocessing import MinMaxScaler
import numpy as np


def normalize_array(arr):
    try:
        scaler = MinMaxScaler()
        result = scaler.fit_transform([[x] for x in arr]).flatten()
        return result.flatten().tolist()
    except Exception as e:
        return f"Error: {str(e)}"
