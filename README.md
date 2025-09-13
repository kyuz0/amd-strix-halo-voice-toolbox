```
███████╗████████╗██████╗ ██╗██╗  ██╗      ██╗  ██╗ █████╗ ██╗      ██████╗
██╔════╝╚══██╔══╝██╔══██╗██║╚██╗██╔╝      ██║  ██║██╔══██╗██║     ██╔═══██╗
███████╗   ██║   ██████╔╝██║ ╚███╔╝       ███████║███████║██║     ██║   ██║
╚════██║   ██║   ██╔══██╗██║ ██╔██╗       ██╔══██║██╔══██║██║     ██║   ██║
███████║   ██║   ██║  ██║██║██╔╝ ██╗      ██║  ██║██║  ██║███████╗╚██████╔╝
╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝

                                V O I C E                        
```

# STRIX HALO — Voice Toolbox (gfx1151)

A Fedora **toolbox** image with a full **ROCm** environment for **VibeVoice** on **AMD Strix Halo (gfx1151)**.

> Container image: `docker.io/kyuz0/amd-strix-halo-voice:latest`

---

## Table of Contents

* [1. Overview](#1-overview)
* [2. Create & Enter the Toolbox](#2-create--enter-the-toolbox)

  * [2.1. Ubuntu Users](#21-ubuntu-users)
* [3. Get the Model Weights](#3-get-the-model-weights)
* [4. Run the Gradio Demo](#4-run-the-gradio-demo)

  * [4.1. Basic Run](#41-basic-run)
  * [4.2. SSH Port Forwarding](#42-ssh-port-forwarding)
* [5. Custom Voices (Outside the Toolbox)](#5-custom-voices-outside-the-toolbox)
* [6. Paths & Persistence](#6-paths--persistence)
* [7. Notes & Caveats](#7-notes--caveats)
* [8. Credits & Links](#8-credits--links)

---

## 1. Overview

This toolbox provides a ready-to-run environment for **VibeVoice** (Microsoft) on **gfx1151** with ROCm. All model weights and **custom voices** live in your **HOME** directory so they persist across container rebuilds.

---

## 2. Create & Enter the Toolbox

Create a toolbox that exposes the GPU devices and adds the right groups:

```bash
toolbox create strix-halo-voice \
  --image docker.io/kyuz0/amd-strix-halo-voice:latest \
  -- --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render --security-opt seccomp=unconfined
```

Enter it:

```bash
toolbox enter strix-halo-voice
```

> **Why these flags?**
>
> * `--device /dev/dri` → graphics/video devices
> * `--device /dev/kfd` → ROCm compute
> * `--group-add video,render` → user gets GPU access
> * `--security-opt seccomp=unconfined` → avoids GPU syscall sandbox issues

### 2.1. Ubuntu Users

On Ubuntu, extra steps are required to allow toolbox containers access to the GPU. Without these, ROCm may fail to see `/dev/kfd` and `/dev/dri`.

Create `/etc/udev/rules.d/99-amd-kfd.rules` with:

```
SUBSYSTEM=="kfd", GROUP="render", MODE="0666", OPTIONS+="last_rule"
SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="render", MODE="0666", OPTIONS+="last_rule"
```

Reload udev or reboot afterwards.

---

## 3. Get the Model Weights

Microsoft retracted the original weights; a community mirror exists. Download with **Hugging Face CLI** into your **HOME** (persistent):

```bash
HF_HUB_ENABLE_HF_TRANSFER=1 hf download aoi-ot/VibeVoice-Large --local-dir "$HOME/VibeVoice-Large"
```

---

## 4. Run the Gradio Demo

### 4.1. Basic Run

```bash
cd /opt/VibeVoice
python demo/gradio_demo.py \
  --model_path "$HOME/VibeVoice-Large/" \
  --port 8000 
```

Open: [http://localhost:8000](http://localhost:8000)

### 4.2. SSH Port Forwarding

If running remotely, forward the port:

```bash
ssh -L 8000:localhost:8000 user@your-strix-halo-host
```

Open locally: [http://localhost:8000](http://localhost:8000)

---

## 5. Custom Voices (Outside the Toolbox)

By **default**, the demo looks for custom voices in `~/voices` (on the **host**). Keep all your `.wav` samples there so they survive toolbox refreshes.

```bash
mkdir -p "$HOME/voices"
# put your voice samples here, e.g.
cp my_speaker.wav "$HOME/voices/"
```

You can also point the script to a different folder:

```bash
python demo/gradio_demo.py \
  --model_path "$HOME/VibeVoice-Large/" \
  --port 8000 \
  --custom-voices-folder "$HOME/my-other-voices"
```

> **Tip:** If you previously kept voices under `/opt/VibeVoice/demo/voices`, move them to `~/voices` so they’re not lost when the container is rebuilt.

---

## 6. Paths & Persistence

| What             | Where (host HOME)              |
| ---------------- | ------------------------------ |
| Model weights    | `~/VibeVoice-Large/`           |
| Custom voices    | `~/voices/`                    |
| Any outputs/temp | Working dir under your `$HOME` |

Everything above is **outside** the toolbox/container, so it persists across updates.

---

## 7. Notes & Caveats

* **Responsible use:** Only use voices you have rights to. Avoid impersonation/misuse.
* **GPU access:** On Ubuntu, ensure you’ve applied the udev rules above. On Fedora, just ensure your user is in `video` and `render` groups.
* **Stability:** This is a lean voice toolbox; if you need unified memory tuning for very large models, see your image/video toolbox notes.

---

## 8. Credits & Links

* VibeVoice (Microsoft) — original project & demos
* Docker image: `docker.io/kyuz0/amd-strix-halo-voice`

