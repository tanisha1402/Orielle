import { useState } from "react";
import { RefreshCw, Sparkles } from "lucide-react";
import { sound } from "../utils/audio";

const radarFacts = [
  "SAR stands for Synthetic Aperture Radar. A satellite uses its motion to act like a much longer antenna.",
  "Radar is an active sensor: it sends its own microwave pulse, so it can observe at night.",
  "Microwaves pass through most clouds, which is why radar is useful during stormy conditions.",
  "Calm open water often looks dark because it reflects much of the radar pulse away from the satellite.",
  "Sentinel-1 uses C-band radar with a wavelength of about 5.6 cm.",
  "The grainy look of radar images is called speckle, caused by many small echoes combining within each pixel.",
  "VV and VH describe how the radar wave is sent and received: vertical out, then vertical or horizontal back.",
  "Buildings can look very bright when walls and the ground bounce radar energy back toward the satellite.",
];

export function RadarFactCard() {
  const [factIndex, setFactIndex] = useState(0);

  const nextFact = () => {
    sound.playRadarPing();
    setFactIndex((index) => (index + 1) % radarFacts.length);
  };

  return (
    <aside aria-label="Radar training fact" className="radar-fact-card">
      <div className="radar-fact-heading">
        <Sparkles aria-hidden="true" size={15} />
        <span>RADAR FACT · TRAINING ONLY</span>
      </div>
      <p aria-live="polite" key={factIndex}>
        {radarFacts[factIndex]}
      </p>
      <button onClick={nextFact} type="button">
        <RefreshCw aria-hidden="true" size={13} />
        Another fact
      </button>
    </aside>
  );
}
