import { useState } from "react";
import { Check, Coins, LockKeyhole, Palette } from "lucide-react";
import { sound } from "../utils/audio";
import {
  COSMETIC_THEMES,
  loadLocalGameState,
  saveLocalGameState,
  type LocalGameState,
} from "../gamification/localGameState";

export function CosmeticShop() {
  const [state, setState] = useState<LocalGameState>(loadLocalGameState);
  const [message, setMessage] = useState("");

  const choose = (themeId: string, cost: number) => {
    const current = loadLocalGameState();
    const owned = current.ownedThemes.includes(themeId);
    if (!owned && current.coins < cost) {
      setMessage("Earn more local coins in the Arcade to unlock this theme.");
      return;
    }
    const next: LocalGameState = {
      ...current,
      coins: owned ? current.coins : current.coins - cost,
      ownedThemes: owned
        ? current.ownedThemes
        : [...current.ownedThemes, themeId],
      activeTheme: themeId,
    };
    if (!saveLocalGameState(next)) {
      setMessage("Could not save your look in this browser.");
      return;
    }
    setState(next);
    setMessage(owned ? "Theme equipped." : "Theme unlocked and equipped.");
    sound.playSuccessChime();
  };

  return (
    <section className="cosmetic-shop reference-game-card reference-game-card--gold">
      <header className="journal-section-heading">
        <div>
          <p className="reference-eyebrow"><Palette size={14} /> PERSONAL STYLE</p>
          <h2>COIN SHOP</h2>
        </div>
        <span className="shop-wallet"><Coins size={16} /> {state.coins} local coins</span>
      </header>
      <p className="shop-caption">
        Unlock pilot-profile accents with Arcade coins. Coins and themes are saved only in this browser.
      </p>
      <div className="shop-themes">
        {COSMETIC_THEMES.map((theme) => {
          const owned = state.ownedThemes.includes(theme.id);
          const active = state.activeTheme === theme.id;
          return (
            <button
              aria-pressed={active}
              className={`shop-theme${active ? " is-active" : ""}`}
              key={theme.id}
              onClick={() => choose(theme.id, theme.cost)}
              style={{ "--theme-accent": theme.accent } as React.CSSProperties}
              type="button"
            >
              <span className="shop-theme__swatch" />
              <strong>{theme.name}</strong>
              <small>
                {active ? <><Check size={12} /> EQUIPPED</> : owned ? "OWNED · EQUIP" : <><LockKeyhole size={11} /> {theme.cost} COINS</>}
              </small>
            </button>
          );
        })}
      </div>
      {message && <p className="shop-message" role="status">{message}</p>}
    </section>
  );
}
