from fastapi import FastAPI

app = FastAPI(title="FastAPI Docker Deployment")

@app.get("/")
def home():
    return {
        "message": "FastAPI application is running!"
    }

@app.get("/health")
def health():
    return {
        "status": "healthy"
    }

@app.get("/items/{item_id}")
def get_item(item_id: int):
    return {
        "item_id": item_id,
        "name": "Sample Item"
    }
