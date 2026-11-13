import { useRef, useState } from "react";
import { ImagePlus, NotebookPen, Trash2 } from "lucide-react";
import { sound } from "../utils/audio";

interface Memory {
  id: string;
  createdAt: string;
  title: string;
  text: string;
  sticker: string;
  photo?: string;
}

const STORAGE_KEY = "terralens.memories.v1";
const STICKERS = ["🌊", "🛰️", "🌧️", "🌱", "😮", "😊", "💡", "❤️"];
const COLORS = ["#ffd166", "#7df9ff", "#f9a8d4", "#86efac", "#c4b5fd"];
const MAX_TEXT_LENGTH = 500;

function readMemories(): Memory[] {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    if (!stored) return [];
    const parsed: unknown = JSON.parse(stored);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (item): item is Memory =>
        typeof item === "object" &&
        item !== null &&
        typeof item.id === "string" &&
        typeof item.text === "string" &&
        typeof item.createdAt === "string" &&
        typeof item.sticker === "string",
    );
  } catch {
    return [];
  }
}

function storeMemories(memories: Memory[]): boolean {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(memories));
    return true;
  } catch {
    return false;
  }
}

function compressPhoto(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      const scale = Math.min(1, 640 / Math.max(image.width, image.height));
      const canvas = document.createElement("canvas");
      canvas.width = Math.max(1, Math.round(image.width * scale));
      canvas.height = Math.max(1, Math.round(image.height * scale));
      const context = canvas.getContext("2d");
      URL.revokeObjectURL(objectUrl);
      if (!context) {
        reject(new Error("This browser could not process the selected photo."));
        return;
      }
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      try {
        resolve(canvas.toDataURL("image/jpeg", 0.78));
      } catch {
        reject(new Error("This photo could not be saved in browser storage."));
      }
    };
    image.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error("This image file could not be opened."));
    };
    image.src = objectUrl;
  });
}

export function Memories() {
  const [memories, setMemories] = useState(readMemories);
  const [title, setTitle] = useState("");
  const [text, setText] = useState("");
  const [sticker, setSticker] = useState(STICKERS[0]);
  const [photo, setPhoto] = useState<string | undefined>();
  const [message, setMessage] = useState("");
  const fileInput = useRef<HTMLInputElement>(null);

  const commit = (next: Memory[]) => {
    if (!storeMemories(next)) {
      setMessage("Browser storage is full. Remove a photo or an older note, then try again.");
      return false;
    }
    setMemories(next);
    setMessage("");
    return true;
  };

  const addMemory = () => {
    if (!text.trim()) return;
    const memory: Memory = {
      id: window.crypto.randomUUID(),
      createdAt: new Date().toISOString(),
      title: title.trim(),
      text: text.trim(),
      sticker,
      photo,
    };
    if (!commit([memory, ...memories])) return;
    setTitle("");
    setText("");
    setPhoto(undefined);
    if (fileInput.current) fileInput.current.value = "";
    sound.playSuccessChime();
  };

  const removeMemory = (id: string) => {
    if (window.confirm("Delete this personal memory?")) {
      commit(memories.filter((memory) => memory.id !== id));
    }
  };

  return (
    <section className="journal-memories">
      <header className="journal-section-heading">
        <div>
          <p className="reference-eyebrow"><NotebookPen size={14} /> PRIVATE SCRAPBOOK</p>
          <h2>MY MEMORIES</h2>
        </div>
        <span>Saved in this browser</span>
      </header>
      <div className="memory-composer">
        <label>
          <span>NOTE TITLE</span>
          <input
            maxLength={60}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Optional title"
            value={title}
          />
        </label>
        <label>
          <span>WHAT DO YOU WANT TO REMEMBER?</span>
          <textarea
            maxLength={MAX_TEXT_LENGTH}
            onChange={(event) => setText(event.target.value)}
            placeholder="A question, an idea, or something you learned…"
            rows={3}
            value={text}
          />
        </label>
        <div className="memory-composer__footer">
          <div className="memory-stickers" aria-label="Choose a memory sticker">
            {STICKERS.map((item) => (
              <button
                aria-label={`Use ${item} sticker`}
                aria-pressed={sticker === item}
                className={sticker === item ? "is-selected" : ""}
                key={item}
                onClick={() => setSticker(item)}
                type="button"
              >
                {item}
              </button>
            ))}
          </div>
          <span className="memory-counter">{text.length}/{MAX_TEXT_LENGTH}</span>
        </div>
        <div className="memory-actions">
          <button
            className="reference-button reference-button--quiet"
            onClick={() => fileInput.current?.click()}
            type="button"
          >
            <ImagePlus size={16} /> {photo ? "CHANGE PHOTO" : "ADD PHOTO"}
          </button>
          <input
            accept="image/*"
            aria-label="Choose a photo for this memory"
            className="visually-hidden"
            onChange={async (event) => {
              const file = event.target.files?.[0];
              if (!file) return;
              if (!file.type.startsWith("image/")) {
                setMessage("Choose an image file.");
                return;
              }
              try {
                setPhoto(await compressPhoto(file));
                setMessage("");
              } catch (error) {
                setMessage(error instanceof Error ? error.message : "Could not read the image.");
              }
            }}
            ref={fileInput}
            type="file"
          />
          {photo && (
            <img className="memory-photo-preview" src={photo} alt="Selected memory photo preview" />
          )}
          {photo && (
            <button className="memory-remove-photo" onClick={() => setPhoto(undefined)} type="button">
              Remove photo
            </button>
          )}
          <button
            className="reference-button reference-button--gold memory-save"
            disabled={!text.trim()}
            onClick={addMemory}
            type="button"
          >
            SAVE MEMORY
          </button>
        </div>
        {message && <p className="memory-message" role="status">{message}</p>}
      </div>

      {memories.length === 0 ? (
        <p className="memory-empty">No saved memories yet. Add a note to start your scrapbook.</p>
      ) : (
        <div className="memory-grid">
          {memories.map((memory, index) => (
            <article
              className="memory-note"
              key={memory.id}
              style={{
                background: COLORS[index % COLORS.length],
                transform: `rotate(${index % 2 ? 1.4 : -1.4}deg)`,
              }}
            >
              <span className="memory-note__sticker" aria-hidden="true">{memory.sticker}</span>
              <button
                aria-label={`Delete memory${memory.title ? `: ${memory.title}` : ""}`}
                className="memory-note__delete"
                onClick={() => removeMemory(memory.id)}
                type="button"
              >
                <Trash2 size={15} />
              </button>
              <time dateTime={memory.createdAt}>
                {new Date(memory.createdAt).toLocaleDateString(undefined, {
                  day: "numeric",
                  month: "short",
                  year: "numeric",
                })}
              </time>
              {memory.title && <h3>{memory.title}</h3>}
              {memory.photo && <img src={memory.photo} alt={memory.title ? `Photo for ${memory.title}` : "Memory attachment"} />}
              <p>{memory.text}</p>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
