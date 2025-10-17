from sklearn.preprocessing import normalize
import numpy as np


def normalize_array(arr):
    try:
        arr_np = np.array(arr).reshape(1, -1)  # single sample
        normalized = normalize(arr_np, norm='l2')  # or 'l1', 'max'
        return normalized.flatten().tolist()
    except Exception as e:
        return f"Error: {str(e)}"
