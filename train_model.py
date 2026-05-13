import pandas as pd
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.preprocessing import StandardScaler, PowerTransformer
from sklearn.linear_model import SGDRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import mlflow
import numpy as np
import joblib


def scale_frame(df):
    X = df.drop(columns=['MedHouseVal'])
    y = df['MedHouseVal']
    scaler = StandardScaler()
    power_trans = PowerTransformer()
    X_scaled = scaler.fit_transform(X)
    y_transformed = power_trans.fit_transform(y.values.reshape(-1, 1))
    return X_scaled, y_transformed, power_trans


def eval_metrics(actual, pred):
    rmse = np.sqrt(mean_squared_error(actual, pred))
    mae = mean_absolute_error(actual, pred)
    r2 = r2_score(actual, pred)
    return rmse, mae, r2


if __name__ == "__main__":
    df = pd.read_csv("california_housing_clean.csv")
    X, y_transformed, power_trans = scale_frame(df)

    X_train, X_val, y_train, y_val = train_test_split(
        X, y_transformed, test_size=0.3, random_state=42
    )

    param_grid = {
        'alpha': [0.0001, 0.001, 0.01],
        'penalty': ['l2', 'l1', 'elasticnet'],
        'loss': ['squared_error', 'huber'],
        'fit_intercept': [True, False]
    }

    mlflow.set_experiment("california_housing_sgd")
    with mlflow.start_run():
        base_model = SGDRegressor(random_state=42, max_iter=2000)
        grid_search = GridSearchCV(base_model, param_grid, cv=3, scoring='r2', n_jobs=-1)
        grid_search.fit(X_train, y_train.ravel())

        best_model = grid_search.best_estimator_
        y_pred_transformed = best_model.predict(X_val)
        y_pred = power_trans.inverse_transform(y_pred_transformed.reshape(-1, 1)).ravel()
        y_true = power_trans.inverse_transform(y_val.reshape(-1, 1)).ravel()

        rmse, mae, r2 = eval_metrics(y_true, y_pred)

        mlflow.log_params(best_model.get_params())
        mlflow.log_metric("rmse", rmse)
        mlflow.log_metric("mae", mae)
        mlflow.log_metric("r2", r2)

        mlflow.sklearn.log_model(best_model, "model")
        joblib.dump(best_model, "california_model.pkl")

        runs = mlflow.search_runs()
        best_run = runs.loc[runs['metrics.r2'].idxmax()]
        model_uri = best_run['artifact_uri'].replace("file://", "") + "/model"
        with open("best_model_uri.txt", "w") as f:
            f.write(model_uri)

        print(f"Лучшая модель сохранена по URI: {model_uri}")
