"""AI RAG pipeline tests."""

from app.ai.language_detector import detect_language
from app.ai.vector_store import InMemoryVectorStore


def test_detect_cebuano_language():
  assert detect_language("Unsa akong sakyan padulong sa Robinson?") == "ceb"


def test_detect_tagalog_language():
  assert detect_language("Paano pumunta sa SM Butuan?") == "tl"


def test_retrieval_finds_route_information():
  store = InMemoryVectorStore()
  store.add_documents(
    [
      {
        "document_id": "route-2",
        "title": "R2 — Junction to Robinsons",
        "category": "transport",
        "chunks": [
          "Route R2 connects Baan Junction to Robinsons Place Butuan.",
        ],
        "metadata": {"route_code": "R2"},
      }
    ]
  )
  results = store.search("Which jeep goes to Robinsons?")
  assert results
  assert "R2" in results[0].content or "Robinsons" in results[0].content


def test_chat_endpoint(client):
  response = client.post(
    "/api/ai/chat",
    json={"message": "Which jeep goes to Robinsons Place Butuan?"},
  )
  assert response.status_code == 200
  data = response.get_json()
  assert "response" in data
  assert data["language"] in {"en", "tl", "ceb", "mixed"}
  assert "session_id" in data


def test_off_topic_question_is_declined(client):
  response = client.post(
    "/api/ai/chat",
    json={"message": "Can you help me with my homework about politics?"},
  )
  assert response.status_code == 200
  data = response.get_json()
  assert "transportation" in data["response"].lower()
