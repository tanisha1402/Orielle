import { useEffect, useRef, useState } from "react";
import {
  ArrowRight,
  Clock3,
  Coins,
  Flame,
  Gamepad2,
  RotateCcw,
  Sparkles,
  Trophy,
} from "lucide-react";
import { sound } from "../utils/audio";
import {
  loadLocalGameState,
  LOCAL_GAME_STATE_EVENT,
  saveLocalGameState,
  touchLocalStreak,
  type LocalGameState,
} from "../gamification/localGameState";

const SPEED_QUESTIONS = [
  {
    question: "Why can SAR collect observations at night?",
    options: ["It sends its own microwave pulse", "It uses moonlight", "It measures heat"],
    correct: 0,
  },
  {
    question: "What does SAR stand for?",
    options: ["Surface Area Reading", "Synthetic Aperture Radar", "Satellite Altitude Record"],
    correct: 1,
  },
  {
    question: "What is speckle?",
    options: ["A cloud shadow", "A map projection", "Grainy variation from radar echoes"],
    correct: 2,
  },
  {
    question: "Calm open water often looks dark because it can…",
    options: ["Reflect energy away from the sensor", "Absorb every wavelength", "Block the satellite"],
    correct: 0,
  },
  {
    question: "VV and VH describe…",
    options: ["Cloud types", "Transmit and receive polarizations", "Image colors"],
    correct: 1,
  },
  {
    question: "A threshold-based water mask is best described as…",
    options: ["A heuristic classification", "Ground truth", "A direct rainfall measurement"],
    correct: 0,
  },
  {
    question: "What can a before/after comparison establish by itself?",
    options: ["The exact cause of change", "Observed difference between acquisitions", "The flood start time"],
    correct: 1,
  },
] as const;

const SPOT_ROUNDS = [
  "Which simplified radar response is more consistent with calm, open water?",
  "Pick the smooth-surface response that may reflect energy away from the sensor.",
  "Which schematic pattern represents a lower radar return?",
  "Find the low-return concept; this is a learning diagram, not a satellite image.",
  "Which abstract response could be associated with smooth water?",
  "One last scan: select the lower-return schematic.",
] as const;

type SpotPattern = "low" | "high";

function Schematic({ pattern }: { pattern: SpotPattern }) {
  return (
    <div
      aria-hidden="true"
      className={`arcade-schematic arcade-schematic--${pattern}`}
    >
      <span className="arcade-schematic__scan" />
      {Array.from({ length: 16 }, (_, index) => (
        <i
          key={index}
          style={{
            left: `${12 + (index % 4) * 24}%`,
            top: `${15 + Math.floor(index / 4) * 23}%`,
            animationDelay: `${(index % 6) * 100}ms`,
          }}
        />
      ))}
    </div>
  );
}

function persist(
  current: LocalGameState,
  patch: Partial<LocalGameState>,
  coinsEarned = 0,
): { state: LocalGameState; saved: boolean } {
  const next = {
    ...current,
    ...patch,
    coins: Math.max(0, current.coins + coinsEarned),
  };
  const saved = saveLocalGameState(next);
  return { state: saved ? next : current, saved };
}

export function ArcadeHub() {
  const [storageMessage, setStorageMessage] = useState("");
  const [gameState, setGameState] = useState<LocalGameState>(() => {
    return touchLocalStreak(loadLocalGameState());
  });
  const [spotIndex, setSpotIndex] = useState(0);
  const [spotStarted, setSpotStarted] = useState(false);
  const [spotChoice, setSpotChoice] = useState<SpotPattern | null>(null);
  const [spotCorrectOn, setSpotCorrectOn] = useState<"left" | "right">("left");
  const [spotScore, setSpotScore] = useState(0);
  const [spotDone, setSpotDone] = useState(false);
  const [speedStarted, setSpeedStarted] = useState(false);
  const [speedActive, setSpeedActive] = useState(false);
  const [speedEndsAt, setSpeedEndsAt] = useState(0);
  const [secondsLeft, setSecondsLeft] = useState(30);
  const [speedIndex, setSpeedIndex] = useState(0);
  const [speedScore, setSpeedScore] = useState(0);
  const [speedCombo, setSpeedCombo] = useState(0);
  const [speedAnswer, setSpeedAnswer] = useState<number | null>(null);
  const spotAwarded = useRef(false);
  const speedAwarded = useRef(false);
  const speedScoreRef = useRef(0);

  useEffect(() => {
    const refresh = () => setGameState(loadLocalGameState());
    window.addEventListener("storage", refresh);
    window.addEventListener(LOCAL_GAME_STATE_EVENT, refresh);
    if (!saveLocalGameState(gameState)) {
      setStorageMessage("Arcade progress could not be saved in this browser.");
    }
    return () => {
      window.removeEventListener("storage", refresh);
      window.removeEventListener(LOCAL_GAME_STATE_EVENT, refresh);
    };
  }, []);

  useEffect(() => {
    if (!speedActive) return;
    const timer = window.setInterval(() => {
      const remaining = Math.max(0, Math.ceil((speedEndsAt - Date.now()) / 1000));
      setSecondsLeft(remaining);
      if (remaining === 0) setSpeedActive(false);
    }, 150);
    return () => window.clearInterval(timer);
  }, [speedActive, speedEndsAt]);

  useEffect(() => {
    if (speedActive || !speedStarted || speedAwarded.current) return;
    speedAwarded.current = true;
    const result = persist(
      loadLocalGameState(),
      { bestSpeed: Math.max(gameState.bestSpeed, speedScoreRef.current) },
      speedScoreRef.current,
    );
    setGameState(result.state);
    setStorageMessage(result.saved ? "" : "Arcade progress could not be saved in this browser.");
    if (result.saved) sound.playTrophyFanfare();
  }, [gameState.bestSpeed, speedActive, speedStarted]);

  const beginSpot = () => {
    setSpotIndex(0);
    setSpotScore(0);
    setSpotChoice(null);
    setSpotDone(false);
    setSpotCorrectOn(Math.random() < 0.5 ? "left" : "right");
    setSpotStarted(true);
    spotAwarded.current = false;
    sound.playLaunchFanfare();
  };

  const chooseSpot = (side: "left" | "right") => {
    if (spotChoice || spotDone) return;
    const correct = side === spotCorrectOn;
    setSpotChoice(correct ? "low" : "high");
    if (correct) {
      setSpotScore((score) => score + 1);
      sound.playSuccessChime();
    } else {
      sound.playRadarPing();
    }
  };

  const nextSpot = () => {
    if (spotIndex === SPOT_ROUNDS.length - 1) {
      if (!spotAwarded.current) {
        spotAwarded.current = true;
        const finalScore = spotScore;
        const result = persist(
          loadLocalGameState(),
          { bestSpot: Math.max(gameState.bestSpot, finalScore) },
          finalScore,
        );
        setGameState(result.state);
        setStorageMessage(result.saved ? "" : "Arcade progress could not be saved in this browser.");
        setSpotDone(true);
        if (result.saved) sound.playTrophyFanfare();
      }
      return;
    }
    setSpotIndex((index) => index + 1);
    setSpotChoice(null);
    setSpotCorrectOn(Math.random() < 0.5 ? "left" : "right");
  };

  const startSpeedRound = () => {
    setSpeedIndex(0);
    setSpeedScore(0);
    speedScoreRef.current = 0;
    setSpeedCombo(0);
    setSpeedAnswer(null);
    setSecondsLeft(30);
    setSpeedEndsAt(Date.now() + 30_000);
    setSpeedStarted(true);
    setSpeedActive(true);
    speedAwarded.current = false;
    sound.playLaunchFanfare();
  };

  const answerSpeed = (choice: number) => {
    if (!speedActive || speedAnswer !== null) return;
    setSpeedAnswer(choice);
    const correct = choice === SPEED_QUESTIONS[speedIndex % SPEED_QUESTIONS.length].correct;
    if (correct) {
      const nextScore = speedScore + 1 + Math.min(speedCombo, 4);
      setSpeedScore(nextScore);
      speedScoreRef.current = nextScore;
      setSpeedCombo((combo) => combo + 1);
      sound.playSuccessChime();
    } else {
      setSpeedCombo(0);
      sound.playRadarPing();
    }
    window.setTimeout(() => {
      setSpeedAnswer(null);
      setSpeedIndex((index) => index + 1);
    }, 550);
  };

  const activeQuestion = SPEED_QUESTIONS[speedIndex % SPEED_QUESTIONS.length];
  const spotLowSide = spotCorrectOn;
  const spotPatternForSide = (side: "left" | "right"): SpotPattern =>
    side === spotLowSide ? "low" : "high";

  return (
    <main className="arcade-page reference-page">
      <header className="reference-page-heading">
        <div>
          <p className="reference-eyebrow"><Gamepad2 size={15} /> TRAINING DECK</p>
          <h1 className="reference-title">ARCADE</h1>
          <p className="reference-subtitle">
            Play quick radar-concept games. Scores and cosmetic coins stay on this device.
          </p>
        </div>
        <div className="arcade-wallet" aria-label={`${gameState.coins} local cosmetic coins`}>
          <Coins size={19} />
          <strong>{gameState.coins}</strong>
          <span>LOCAL COINS</span>
        </div>
      </header>

      <div className="arcade-layout">
        <section className="arcade-games">
          <article className="reference-game-card reference-game-card--cyan">
            <div className="reference-game-card__top">
              <span className="reference-sticker">6 ROUNDS</span>
              <span className="arcade-best"><Trophy size={14} /> BEST {gameState.bestSpot}/6</span>
            </div>
            <h2>SPOT THE FLOOD</h2>
            <span className="training-label">RADAR CONCEPT SIMULATION</span>
            {!spotStarted ? (
              <>
                <p>Compare two abstract radar-return patterns and spot the low-return concept often associated with calm open water.</p>
                <button className="reference-button reference-button--gold" onClick={beginSpot} type="button">
                  PLAY <ArrowRight size={16} />
                </button>
              </>
            ) : spotDone ? (
              <div className="arcade-finish">
                <strong>{spotScore} / {SPOT_ROUNDS.length}</strong>
                <p>{spotScore === SPOT_ROUNDS.length ? "Perfect scan!" : "Good practice—watch for the smoother, lower-return pattern."}</p>
                <button className="reference-button reference-button--gold" onClick={beginSpot} type="button">
                  <RotateCcw size={15} /> PLAY AGAIN
                </button>
              </div>
            ) : (
              <>
                <div className="arcade-round-track" aria-label={`Round ${spotIndex + 1} of ${SPOT_ROUNDS.length}`}>
                  {SPOT_ROUNDS.map((_, index) => (
                    <span className={index < spotIndex ? "is-done" : index === spotIndex ? "is-current" : ""} key={index}>
                      {index + 1}
                    </span>
                  ))}
                  <b>{spotScore} ★</b>
                </div>
                <p className="arcade-prompt">{SPOT_ROUNDS[spotIndex]}</p>
                <div className="arcade-pattern-choices">
                  {(["left", "right"] as const).map((side) => {
                    const pattern = spotPatternForSide(side);
                    return (
                      <button
                        aria-label={`Pattern ${side === "left" ? "A" : "B"}${spotChoice ? `, ${pattern === "low" ? "lower return" : "stronger return"}` : ""}`}
                        className={`arcade-pattern-choice${spotChoice && pattern === "low" ? " is-correct" : ""}${spotChoice && pattern === "high" ? " is-other" : ""}`}
                        disabled={spotChoice !== null}
                        key={side}
                        onClick={() => chooseSpot(side)}
                        type="button"
                      >
                        <Schematic pattern={pattern} />
                        <span>PATTERN {side === "left" ? "A" : "B"}</span>
                        {spotChoice && <small>{pattern === "low" ? "LOW RETURN" : "STRONGER RETURN"}</small>}
                      </button>
                    );
                  })}
                </div>
                {spotChoice && (
                  <div className="arcade-feedback" aria-live="polite">
                    <span>{spotChoice === "low" ? "NICE SCAN" : "TRY THE LOWER RETURN"}</span>
                    <p>These are conceptual diagrams, not Sentinel-1 imagery. Smooth water can reflect radar energy away; context and validation still matter.</p>
                    <button className="reference-button reference-button--gold" onClick={nextSpot} type="button">
                      {spotIndex === SPOT_ROUNDS.length - 1 ? "FINISH" : "NEXT SCAN"} <ArrowRight size={15} />
                    </button>
                  </div>
                )}
              </>
            )}
          </article>

          <article className="reference-game-card reference-game-card--amber">
            <div className="reference-game-card__top">
              <span className="reference-sticker">30 SECONDS</span>
              <span className="arcade-best"><Trophy size={14} /> BEST {gameState.bestSpeed} PTS</span>
            </div>
            <h2>SPEED ROUND</h2>
            <span className="training-label">RADAR KNOWLEDGE · NO XP</span>
            {!speedStarted || (!speedActive && speedAwarded.current) ? (
              <>
                <p>Race the clock through short radar-literacy questions. Correct answers build a combo; rewards are local cosmetic coins only.</p>
                <button className="reference-button reference-button--gold" onClick={startSpeedRound} type="button">
                  {speedStarted ? "PLAY AGAIN" : "START ROUND"} <ArrowRight size={16} />
                </button>
              </>
            ) : (
              <div className="speed-round" aria-live="polite">
                <div className={`speed-timer${secondsLeft <= 8 ? " is-low" : ""}`}>
                  <Clock3 size={17} /> {secondsLeft}s <span>{speedScore} PTS</span>
                </div>
                <p className="arcade-prompt">{activeQuestion.question}</p>
                <div className="speed-options">
                  {activeQuestion.options.map((option, index) => (
                    <button
                      className={
                        speedAnswer === index
                          ? index === activeQuestion.correct
                            ? "is-correct"
                            : "is-wrong"
                          : ""
                      }
                      disabled={speedAnswer !== null || !speedActive}
                      key={option}
                      onClick={() => answerSpeed(index)}
                      type="button"
                    >
                      <span>{String.fromCharCode(65 + index)}</span>{option}
                    </button>
                  ))}
                </div>
                <div className="speed-combo"><Flame size={15} /> COMBO {speedCombo}</div>
              </div>
            )}
          </article>
        </section>

        <aside className="arcade-sidebar">
          <section className="reference-streak-card">
            <Flame className="reference-flame" size={37} />
            <strong>{gameState.streak.count}-DAY STREAK</strong>
            <div className="streak-dots" aria-label={`${Math.min(gameState.streak.count, 7)} of 7 streak days`}>
              {Array.from({ length: 7 }, (_, index) => (
                <span className={index < gameState.streak.count ? "is-lit" : ""} key={index}>
                  {index < gameState.streak.count ? "✓" : ""}
                </span>
              ))}
            </div>
            <small>Visit on consecutive days to keep your local streak.</small>
          </section>

          <section className="reference-score-card">
            <h2><Trophy size={17} /> HIGH SCORES</h2>
            <p>Saved on this device—not backend XP.</p>
            <div className="score-row"><span>Spot the Flood</span><strong>{gameState.bestSpot} / 6</strong></div>
            <div className="score-row"><span>Speed Round</span><strong>{gameState.bestSpeed} pts</strong></div>
          </section>

          <section className="reference-score-card arcade-note">
            <Sparkles size={20} />
            <p>Games teach radar concepts with diagrams and questions. They do not display or score real satellite scenes.</p>
          </section>
        </aside>
      </div>
      {storageMessage && (
        <p className="arcade-storage-message" role="status">
          {storageMessage}
        </p>
      )}
    </main>
  );
}
