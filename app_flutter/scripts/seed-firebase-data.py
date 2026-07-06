#!/usr/bin/env python3
"""Seed Firebase emulator with test data matching the FallbackDataSource."""
import json
import sys
import requests

BASE = "http://localhost:8080"
PROJECT = "demo-project"


def _doc_path(collection, doc_id):
    return (
        f"{BASE}/v1/projects/{PROJECT}/databases/(default)/documents"
        f"/{collection}/{doc_id}"
    )


def seed():
    # Create schema types document
    types_payload = {
        "fields": {
            "Item": {
                "stringValue": json.dumps({
                    "displayName": "Item",
                    "iconName": "insert_drive_file",
                    "fields": [
                        {"key": "name", "label": "Name", "type": "string"},
                        {"key": "description", "label": "Description", "type": "string"},
                    ],
                    "childTypes": [
                        {
                            "relationName": "contains",
                            "childTypeName": "SubElement",
                            "childLabel": "Items",
                        }
                    ],
                    "relatedTypes": [
                        {
                            "relationName": "affects",
                            "childTypeName": "Alarm",
                            "childLabel": "Alarms",
                        },
                        {
                            "relationName": "records",
                            "childTypeName": "Event",
                            "childLabel": "Events",
                        },
                    ],
                })
            },
            "SubElement": {
                "stringValue": json.dumps({
                    "displayName": "Sub Element",
                    "iconName": "widgets",
                    "fields": [
                        {"key": "id", "label": "ID", "type": "string"},
                        {"key": "name", "label": "Name", "type": "string"},
                        {"key": "type", "label": "Type", "type": "string"},
                        {"key": "status", "label": "Status", "type": "string"},
                    ],
                })
            },
            "Alarm": {
                "stringValue": json.dumps({
                    "displayName": "Alarm",
                    "iconName": "warning",
                    "fields": [
                        {"key": "id", "label": "Alarm ID", "type": "string"},
                        {"key": "target", "label": "Target", "type": "string"},
                        {"key": "severity", "label": "Severity", "type": "string"},
                        {"key": "timestamp", "label": "Timestamp", "type": "string"},
                    ],
                })
            },
            "Event": {
                "stringValue": json.dumps({
                    "displayName": "Event",
                    "iconName": "event",
                    "fields": [
                        {"key": "id", "label": "Event ID", "type": "string"},
                        {"key": "source", "label": "Source", "type": "string"},
                        {"key": "message", "label": "Message", "type": "string"},
                        {"key": "timestamp", "label": "Timestamp", "type": "string"},
                    ],
                })
            },
        }
    }

    resp = requests.patch(_doc_path("schema", "types"), json=types_payload)
    print(f"Schema seeded: {resp.status_code}")

    # Seed hierarchy document
    hierarchy_payload = {
        "fields": {
            "pairs": {
                "arrayValue": {
                    "values": []
                }
            }
        }
    }
    resp = requests.patch(_doc_path("schema", "hierarchy"), json=hierarchy_payload)
    print(f"Hierarchy seeded: {resp.status_code}")

    # Seed sample data
    for i in range(1, 16):
        elem_id = f"elem-{i}"
        elem_payload = {
            "fields": {
                "parent_node_id": {"stringValue": "Item"},
                "name": {"stringValue": f"Element {i}"},
                "type": {"stringValue": ["Worker", "Collector", "Sensor"][i % 3]},
                "status": {"stringValue": ["Active", "Standby", "Error"][i % 3]},
            }
        }
        requests.patch(_doc_path("elements", elem_id), json=elem_payload)

        alarm_id = f"alarm-{i}"
        alarm_payload = {
            "fields": {
                "parent_node_id": {"stringValue": "Item"},
                "target": {"stringValue": f"Target {i}"},
                "severity": {"stringValue": ["Critical", "Warning", "Info"][i % 3]},
                "timestamp": {"stringValue": f"2026-06-{(i % 28) + 1}"},
            }
        }
        requests.patch(_doc_path("alarms", alarm_id), json=alarm_payload)

        event_id = f"event-{i}"
        event_payload = {
            "fields": {
                "parent_node_id": {"stringValue": "Item"},
                "source": {"stringValue": ["System", "User", "External"][i % 3]},
                "message": {"stringValue": f"Event {i} occurred"},
                "timestamp": {"stringValue": f"2026-06-{(i % 28) + 1}"},
            }
        }
        requests.patch(_doc_path("events", event_id), json=event_payload)

    print(f"Seeded 15 elements, 15 alarms, 15 events")


if __name__ == "__main__":
    seed()
