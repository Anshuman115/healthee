"""Profile edits preserve omitted answers and never freshen restored weight."""

from datetime import date

import pytest

from healthee.read.profile_edit import ProfileEdit


def test_birth_date_is_a_calendar_date() -> None:
    assert ProfileEdit.model_validate({"dob_date": "1994-07-01"}).dob_date == date(1994, 7, 1)


@pytest.mark.parametrize(
    "body",
    [
        {"height_cm": -1},
        {"measured_weight_kg": 0},
        {"sex": "guessed"},
        {"dob_date": "3000-01-01"},
        {"height_cm": float("nan")},
    ],
)
def test_invalid_demographics_are_rejected(body: dict) -> None:
    with pytest.raises(ValueError):
        ProfileEdit.model_validate(body)


def test_partial_edit_preserves_answers_and_weight_date(seeded_client: tuple) -> None:
    client, headers = seeded_client
    before = client.get("/api/profile", headers=headers).json()
    response = client.patch("/api/profile", headers=headers, json={"name": "Updated"})
    assert response.status_code == 200
    assert response.json() == {"ok": True}
    after = client.get("/api/profile", headers=headers).json()
    assert after == {**before, "name": "Updated"}


def test_explicit_birthday_and_weight_roundtrip(seeded_client: tuple) -> None:
    client, headers = seeded_client
    response = client.patch(
        "/api/profile",
        headers=headers,
        json={
            "dob_date": "1994-07-01",
            "height_cm": 180,
            "measured_weight_kg": 74.2,
        },
    )
    assert response.status_code == 200
    profile = client.get("/api/profile", headers=headers).json()
    assert profile["dob_date"] == "1994-07-01"
    assert profile["height_cm"] == 180
    assert profile["weight_kg"] == 74.2


def test_explicit_null_clears_only_that_answer(seeded_client: tuple) -> None:
    client, headers = seeded_client
    response = client.patch("/api/profile", headers=headers, json={"sex": None})
    assert response.status_code == 200
    profile = client.get("/api/profile", headers=headers).json()
    assert profile["sex"] is None
    assert profile["height_cm"] == 176
