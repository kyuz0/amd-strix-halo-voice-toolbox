import torch, torchaudio, numpy as np
from transformers import AutoProcessor, CsmForConditionalGeneration

model_id = "sesame/csm-1b"
device   = "cuda" if torch.cuda.is_available() else "cpu"

processor = AutoProcessor.from_pretrained(model_id)
model     = CsmForConditionalGeneration.from_pretrained(model_id, device_map=device)

# Load & resample your reference to 24kHz mono array
wav, sr = torchaudio.load("me_ref.wav")                # your recording
if sr != 24000:
    wav = torchaudio.functional.resample(wav, sr, 24000)
ref_audio = wav.squeeze(0).numpy()

# (Best) Provide the exact transcript of your reference audio:
ref_text = "<<< put the exact words you said in me_ref.wav here >>>"

# Ask the same 'speaker' (role "0") to say new text
conversation = [
    {"role":"0", "content":[
        {"type":"text",  "text": ref_text},
        {"type":"audio", "audio": ref_audio},
    ]},
    {"role":"0", "content":[
        {"type":"text", "text": "Thanks for calling. How can I help today?"}
    ]},
]

inputs = processor.apply_chat_template(conversation, tokenize=True, return_dict=True).to(device)
audio  = model.generate(**inputs, output_audio=True)
processor.save_audio(audio, "clone.wav")
