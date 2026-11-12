package main

import "testing"

func TestClusterPopularAreasGroupsStartsWithin500m(t *testing.T) {
	places := []Place{{Name: "Meskel Square", Lat: 9.0107, Lng: 38.7610, City: "Addis Ababa"}}
	activities := []Activity{
		{StartLat: 9.0100, StartLng: 38.7600},
		{StartLat: 9.0104, StartLng: 38.7603}, // ~50 m away
		{StartLat: 9.0200, StartLng: 38.7700}, // ~1.4 km away
	}

	areas := clusterPopularAreas(activities, places)
	if len(areas) != 2 {
		t.Fatalf("expected 2 clusters, got %d: %+v", len(areas), areas)
	}
	if areas[0].RunCount != 2 {
		t.Fatalf("expected the first cluster to have 2 starts, got %+v", areas[0])
	}
	if areas[0].Name != "Meskel Square" {
		t.Fatalf("expected landmark name Meskel Square, got %q", areas[0].Name)
	}
	if areas[1].RunCount != 1 {
		t.Fatalf("expected the distant start to be its own cluster, got %+v", areas[1])
	}
}

func TestClusterPopularAreasIgnoresMissingCoordinates(t *testing.T) {
	places := []Place{{Name: "Meskel Square", Lat: 9.0107, Lng: 38.7610, City: "Addis Ababa"}}
	activities := []Activity{
		{StartLat: 0, StartLng: 0},
		{StartLat: 0, StartLng: 0, Track: []TrackPoint{{Lat: 9.0107, Lng: 38.7610}}},
	}

	areas := clusterPopularAreas(activities, places)
	if len(areas) != 1 {
		t.Fatalf("expected one cluster from the track fallback, got %+v", areas)
	}
	if areas[0].RunCount != 1 {
		t.Fatalf("expected the zero-coordinate activity to be skipped, got %+v", areas[0])
	}
}

func TestPopularAreaNameFallsBackToCity(t *testing.T) {
	places := []Place{{Name: "Meskel Square", Lat: 9.0107, Lng: 38.7610, City: "Addis Ababa"}}
	name, city := popularAreaName(places, 9.2000, 38.9000)
	if name != "Addis Ababa training area" || city != "Addis Ababa" {
		t.Fatalf("unexpected fallback name: %q, %q", name, city)
	}
}

func TestPopularAreaNameUsesOpenCountryWhenFarFromKnownPlaces(t *testing.T) {
	places := []Place{{Name: "Meskel Square", Lat: 9.0107, Lng: 38.7610, City: "Addis Ababa"}}
	name, city := popularAreaName(places, 5.0000, 34.0000)
	if name != "Open country" || city != "" {
		t.Fatalf("unexpected open-country fallback: %q, %q", name, city)
	}
}
