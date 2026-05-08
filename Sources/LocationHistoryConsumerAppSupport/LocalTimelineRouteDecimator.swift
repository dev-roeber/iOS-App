import Foundation
import LocationHistoryConsumer

/// Phase-8A — deterministischer, bounded Decimator.
///
/// Entwurfsziele:
/// 1. Iterator-basiert. Es darf nie der **gesamte** Pfad als `[Double]` im
///    RAM stehen. Eingabe ist ein `Sequence` (typisch `CoordBlobIterator`),
///    Ausgabe ist ein `[LocalTimelineMapPoint]` der Länge `<= maxPoints`.
/// 2. Ersten und letzten Punkt **immer** beibehalten, auch wenn das Budget
///    sehr klein ist. Bei `maxPoints == 1` wird nur der erste behalten.
/// 3. Stride-/Budget-basiert. Douglas-Peucker bleibt Phase-8B/9.
/// 4. Leere oder 1-Punkt-Pfade sind stabil und kosten 0/1 Punkt.
///
/// Der Decimator hält **nur** den letzten gesehenen Quell-Punkt im
/// Working-Set, plus das Output-Array (≤ `maxPoints`). Damit ist die
/// RAM-Spitze O(maxPoints), nicht O(originalPointCount).
public enum LocalTimelineRouteDecimator {

    /// Reduce a stream of `(lat, lon)` pairs to at most `maxPoints` while
    /// preserving the first and last point.
    ///
    /// - Parameters:
    ///   - source: Quell-Iterator. Muss exakt einmal abrufbar sein.
    ///   - originalPointCount: Falls bekannt, bestimmt das den Stride
    ///     deterministisch. Bei `nil` wird zweifach iteriert wäre
    ///     teuer — stattdessen wird sample-and-keep-last benutzt
    ///     (siehe `decimateUnknownLength`). Für Phase-8A nutzt der
    ///     Provider den bekannten `pointCount`-Pfad.
    ///   - maxPoints: Hartes Obergrenze. Muss `>= 1` sein.
    public static func decimate<S: Sequence>(_ source: S,
                                             originalPointCount: Int,
                                             maxPoints: Int) -> [LocalTimelineMapPoint]
    where S.Element == EncodedCoordinate {
        precondition(maxPoints >= 1, "maxPoints must be >= 1")

        if originalPointCount <= 0 {
            return []
        }
        if originalPointCount <= maxPoints {
            // Klein genug — alles übernehmen, ohne Stride-Logik.
            var out: [LocalTimelineMapPoint] = []
            out.reserveCapacity(originalPointCount)
            for c in source {
                out.append(LocalTimelineMapPoint(latitude: c.latitude,
                                                 longitude: c.longitude))
            }
            return out
        }

        if maxPoints == 1 {
            // Nur ersten Punkt behalten.
            for c in source {
                return [LocalTimelineMapPoint(latitude: c.latitude,
                                              longitude: c.longitude)]
            }
            return []
        }

        // maxPoints >= 2 und originalPointCount > maxPoints.
        // Plan: erster Punkt + (maxPoints - 2) Mittel-Stride-Punkte + letzter Punkt.
        let middleSlots = maxPoints - 2
        // Stride zwischen ausgewählten Mittel-Punkten innerhalb [1 ... originalPointCount-2].
        // Wir verteilen `middleSlots` Stützpunkte gleichmäßig im Index-Bereich
        // [1, originalPointCount - 2].
        let innerCount = originalPointCount - 2
        // floor((index * (middleSlots+1)) / (innerCount+1)) wechselt monoton.
        var out: [LocalTimelineMapPoint] = []
        out.reserveCapacity(maxPoints)

        var lastSeen: EncodedCoordinate?
        var index = 0
        var nextSlot = 1            // wir wollen Slot 1..middleSlots
        var pickedMiddle = 0

        for c in source {
            if index == 0 {
                out.append(LocalTimelineMapPoint(latitude: c.latitude,
                                                 longitude: c.longitude))
            } else if index == originalPointCount - 1 {
                // Letzten Punkt explizit als Letztes anhängen, nach
                // möglichen verbleibenden Mittel-Slots.
                lastSeen = c
                break
            } else if pickedMiddle < middleSlots {
                // Mittel-Index relativ zu [1, originalPointCount - 2].
                let relIndex = index // 1..originalPointCount-2
                // Soll-Position: nextSlot * innerCount / (middleSlots + 1)
                let target = Int((Double(nextSlot) * Double(innerCount)
                                  / Double(middleSlots + 1)).rounded())
                if relIndex >= max(1, target) {
                    out.append(LocalTimelineMapPoint(latitude: c.latitude,
                                                     longitude: c.longitude))
                    pickedMiddle += 1
                    nextSlot += 1
                }
                lastSeen = c
            } else {
                lastSeen = c
            }
            index += 1
        }

        // Falls die Quelle früher endet als versprochen, hängen wir den
        // letzten gesehenen Punkt an (nie das Budget überschreiten).
        if let lastSeen, out.count < maxPoints {
            out.append(LocalTimelineMapPoint(latitude: lastSeen.latitude,
                                             longitude: lastSeen.longitude))
        }

        // Hartes Cap.
        if out.count > maxPoints {
            out.removeLast(out.count - maxPoints)
        }
        return out
    }
}
