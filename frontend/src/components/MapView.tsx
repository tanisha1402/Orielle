import { useEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from "react";
import {
  AttributionControl,
  Map as MapLibreMap,
  NavigationControl,
  setWorkerUrl,
} from "maplibre-gl";
import maplibreWorker from "maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url";
import {
  Eye,
  EyeOff,
  GripVertical,
  Layers3,
  LoaderCircle,
  MapPin,
} from "lucide-react";
import type { ChangeSummary } from "../data/analysis";
import type {
  ApiDataStatus,
  RasterTileJsonSources,
} from "../data/integration";
import { JAMUNA_STUDY_AREA } from "../data/mission";

const BASEMAP_STYLE = "https://tiles.openfreemap.org/styles/dark";
setWorkerUrl(maplibreWorker);

interface MapViewProps {
  rasterTileJson: RasterTileJsonSources;
  analysis: ChangeSummary | null;
  dataStatus: ApiDataStatus;
}

export function MapView({
  rasterTileJson,
  analysis,
  dataStatus,
}: MapViewProps) {
  const afterContainer = useRef<HTMLDivElement>(null);
  const beforeContainer = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const afterMapRef = useRef<MapLibreMap | null>(null);
  const beforeMapRef = useRef<MapLibreMap | null>(null);
  const dragging = useRef(false);
  const [swipePosition, setSwipePosition] = useState(52);
  const [newWaterVisible, setNewWaterVisible] = useState(true);
  const newWaterVisibleRef = useRef(true);
  const [basemapReady, setBasemapReady] = useState(false);
  const [basemapError, setBasemapError] = useState(false);
  const layersConfigured =
    dataStatus === "ready" &&
    Boolean(
      rasterTileJson.before &&
        rasterTileJson.after &&
        rasterTileJson.newWater,
    );

  useEffect(() => {
    newWaterVisibleRef.current = newWaterVisible;
    for (const map of [afterMapRef.current, beforeMapRef.current]) {
      if (map?.getLayer("new-water-layer")) {
        map.setLayoutProperty(
          "new-water-layer",
          "visibility",
          newWaterVisible ? "visible" : "none",
        );
      }
    }
  }, [newWaterVisible]);

  useEffect(() => {
    if (!afterContainer.current || !beforeContainer.current) {
      return;
    }

    let synchronizing = false;
    const afterMap = new MapLibreMap({
      container: afterContainer.current,
      style: BASEMAP_STYLE,
      center: JAMUNA_STUDY_AREA.center,
      zoom: JAMUNA_STUDY_AREA.zoom,
      attributionControl: false,
    });
    const beforeMap = new MapLibreMap({
      container: beforeContainer.current,
      style: BASEMAP_STYLE,
      center: JAMUNA_STUDY_AREA.center,
      zoom: JAMUNA_STUDY_AREA.zoom,
      attributionControl: false,
    });
    afterMapRef.current = afterMap;
    beforeMapRef.current = beforeMap;

    afterMap.addControl(new NavigationControl({ showCompass: false }), "top-right");
    afterMap.addControl(new AttributionControl({ compact: true }), "bottom-right");

    const syncMaps = (source: MapLibreMap, target: MapLibreMap) => {
      if (synchronizing) {
        return;
      }
      synchronizing = true;
      const center = source.getCenter();
      target.jumpTo({
        center: [center.lng, center.lat],
        zoom: source.getZoom(),
        bearing: source.getBearing(),
        pitch: source.getPitch(),
      });
      synchronizing = false;
    };
    const syncAfterToBefore = () => syncMaps(afterMap, beforeMap);
    const syncBeforeToAfter = () => syncMaps(beforeMap, afterMap);
    afterMap.on("move", syncAfterToBefore);
    beforeMap.on("move", syncBeforeToAfter);

    const addRasterLayer = (
      map: MapLibreMap,
      sourceId: string,
      layerId: string,
      tileJsonUrl: string | null,
      opacity: number,
    ) => {
      if (!tileJsonUrl || map.getSource(sourceId)) {
        return;
      }
      map.addSource(sourceId, { type: "raster", url: tileJsonUrl });
      const firstLabelLayer = map
        .getStyle()
        .layers?.find((layer) => layer.type === "symbol")?.id;
      map.addLayer(
        {
          id: layerId,
          type: "raster",
          source: sourceId,
          paint: { "raster-opacity": opacity },
        },
        firstLabelLayer,
      );
    };

    afterMap.on("load", () => {
      addRasterLayer(
        afterMap,
        "after-rtc",
        "after-rtc-layer",
        layersConfigured ? rasterTileJson.after : null,
        0.9,
      );
      addRasterLayer(
        afterMap,
        "new-water",
        "new-water-layer",
        layersConfigured ? rasterTileJson.newWater : null,
        0.82,
      );
      if (afterMap.getLayer("new-water-layer")) {
        afterMap.setLayoutProperty(
          "new-water-layer",
          "visibility",
          newWaterVisibleRef.current ? "visible" : "none",
        );
      }
      setBasemapReady(true);
    });
    beforeMap.on("load", () => {
      addRasterLayer(
        beforeMap,
        "before-rtc",
        "before-rtc-layer",
        layersConfigured ? rasterTileJson.before : null,
        0.9,
      );
      addRasterLayer(
        beforeMap,
        "new-water",
        "new-water-layer",
        layersConfigured ? rasterTileJson.newWater : null,
        0.82,
      );
      if (beforeMap.getLayer("new-water-layer")) {
        beforeMap.setLayoutProperty(
          "new-water-layer",
          "visibility",
          newWaterVisibleRef.current ? "visible" : "none",
        );
      }
    });

    const onMapError = () => {
      if (!afterMap.isStyleLoaded()) {
        setBasemapError(true);
      }
    };
    afterMap.on("error", onMapError);

    return () => {
      afterMap.off("move", syncAfterToBefore);
      beforeMap.off("move", syncBeforeToAfter);
      afterMap.off("error", onMapError);
      afterMap.remove();
      beforeMap.remove();
      if (afterMapRef.current === afterMap) {
        afterMapRef.current = null;
      }
      if (beforeMapRef.current === beforeMap) {
        beforeMapRef.current = null;
      }
    };
  }, [
    layersConfigured,
    rasterTileJson.after,
    rasterTileJson.before,
    rasterTileJson.newWater,
  ]);

  const moveSwipe = (event: PointerEvent<HTMLButtonElement>) => {
    if (!dragging.current || !stage.current) {
      return;
    }
    const bounds = stage.current.getBoundingClientRect();
    const nextPosition = ((event.clientX - bounds.left) / bounds.width) * 100;
    setSwipePosition(Math.max(8, Math.min(92, nextPosition)));
  };

  const handleSwipeKey = (event: KeyboardEvent<HTMLButtonElement>) => {
    const increments: Record<string, number> = {
      ArrowLeft: -2,
      ArrowRight: 2,
      Home: -100,
      End: 100,
    };
    const increment = increments[event.key];
    if (increment === undefined) {
      return;
    }
    event.preventDefault();
    setSwipePosition((position) => Math.max(8, Math.min(92, position + increment)));
  };

  const formattedArea =
    analysis === null
      ? "—"
      : analysis.newWaterAreaKm2.toLocaleString("en", {
          minimumFractionDigits: 3,
          maximumFractionDigits: 3,
        });

  return (
    <div className="map-frame">
      <div className="map-stage" ref={stage}>
        <div aria-label="After observation map" className="map-canvas" ref={afterContainer} />
        <div
          aria-label="Before observation map"
          className="before-map-clip"
          style={{ clipPath: `inset(0 ${100 - swipePosition}% 0 0)` }}
        >
          <div className="map-canvas" ref={beforeContainer} />
        </div>

        <div className="map-kicker">
          <span className="map-kicker-icon">
            <MapPin aria-hidden="true" size={14} />
          </span>
          <span>{JAMUNA_STUDY_AREA.subregion}</span>
          <span className="map-kicker-divider" />
          <span className="basemap-label">
            {basemapReady ? "OpenFreeMap basemap" : "Loading basemap"}
          </span>
        </div>

        <button
          aria-checked={newWaterVisible}
          className="map-layer-toggle"
          disabled={!layersConfigured}
          onClick={() => setNewWaterVisible((visible) => !visible)}
          role="switch"
          type="button"
        >
          {newWaterVisible ? (
            <Eye aria-hidden="true" size={14} />
          ) : (
            <EyeOff aria-hidden="true" size={14} />
          )}
          <span>Observed New Water</span>
        </button>

        <div className="scene-side-label scene-side-label--before">
          <span className="scene-side-dot" />
          BEFORE
        </div>
        <div className="scene-side-label scene-side-label--after">
          <span className="scene-side-dot scene-side-dot--after" />
          AFTER
        </div>

        <div
          aria-label="Before and after swipe divider"
          className="swipe-divider"
          style={{ left: `${swipePosition}%` }}
        >
          <button
            aria-label="Drag to compare before and after observations"
            aria-valuemax={92}
            aria-valuemin={8}
            aria-valuenow={Math.round(swipePosition)}
            className="swipe-handle"
            onKeyDown={handleSwipeKey}
            onPointerDown={(event) => {
              dragging.current = true;
              event.currentTarget.setPointerCapture(event.pointerId);
            }}
            onPointerMove={moveSwipe}
            onPointerUp={(event) => {
              dragging.current = false;
              event.currentTarget.releasePointerCapture(event.pointerId);
            }}
            onPointerCancel={() => {
              dragging.current = false;
            }}
            role="slider"
            type="button"
          >
            <GripVertical aria-hidden="true" size={20} />
          </button>
        </div>

        <div aria-live="polite" className="area-stat-card">
          <div className="area-stat-topline">
            <span className="area-stat-icon">
              <Layers3 aria-hidden="true" size={15} />
            </span>
            <span>Observed new-water extent</span>
          </div>
          <div className="area-stat-value">
            <strong>{formattedArea}</strong>
            <span>km²</span>
          </div>
          <p>
            {analysis
              ? "Calculated from aligned observations"
              : dataStatus === "waiting"
                ? "Waiting for SAR processing"
                : dataStatus === "unavailable"
                  ? "Local backend unavailable"
                  : "Checking local SAR outputs"}
          </p>
        </div>

        <div className="map-data-state" role="status">
          <span className={layersConfigured ? "state-light state-light--ready" : "state-light"} />
          {layersConfigured
            ? "Local SAR layers connected"
            : dataStatus === "waiting"
              ? "Waiting for SAR processing"
              : dataStatus === "unavailable"
                ? "Local backend unavailable"
                : "Checking local SAR outputs"}
        </div>

        <div className="map-legend">
          <span
            className={`legend-swatch${newWaterVisible ? "" : " legend-swatch--hidden"}`}
          />
          <span>
            {layersConfigured && newWaterVisible
              ? "Observed new-water extent"
              : layersConfigured
                ? "New-water overlay hidden"
                : "New-water overlay pending"}
          </span>
        </div>

        {basemapError && (
          <div className="map-error" role="status">
            The basemap could not load. Check your internet connection.
          </div>
        )}
        {!basemapReady && !basemapError && (
          <div className="map-loading" aria-hidden="true">
            <LoaderCircle className="spin" size={17} />
            <span>Connecting to basemap</span>
          </div>
        )}
      </div>
    </div>
  );
}
