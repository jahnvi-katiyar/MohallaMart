export type Coordinates = { latitude: number; longitude: number }
export function getBrowserLocation(): Promise<Coordinates> {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) return reject(new Error('Location is not available in this browser.'))
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => resolve({ latitude: coords.latitude, longitude: coords.longitude }),
      (error) => reject(new Error(error.code === error.PERMISSION_DENIED ? 'Location permission was denied.' : 'Could not get your location.')),
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 300000 },
    )
  })
}
export function distanceKm(from: Coordinates, to: Coordinates) {
  const radians = (degrees: number) => degrees * Math.PI / 180
  const lat = radians(to.latitude - from.latitude), lon = radians(to.longitude - from.longitude)
  const a = Math.sin(lat / 2) ** 2 + Math.cos(radians(from.latitude)) * Math.cos(radians(to.latitude)) * Math.sin(lon / 2) ** 2
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}
