FROM registry.fedoraproject.org/fedora:rawhide

# Base packages (keep compilers/headers for Triton JIT at runtime)
RUN dnf -y install --setopt=install_weak_deps=False --nodocs \
      libdrm-devel python3.13 python3.13-devel git rsync libatomic bash ca-certificates curl \
      gcc gcc-c++ binutils make git ffmpeg-free \
  && dnf clean all && rm -rf /var/cache/dnf/*

# Python venv
RUN /usr/bin/python3.13 -m venv /opt/venv
ENV VIRTUAL_ENV=/opt/venv
ENV PATH=/opt/venv/bin:$PATH
ENV PIP_NO_CACHE_DIR=1
RUN printf 'source /opt/venv/bin/activate\n' > /etc/profile.d/venv.sh
RUN python -m pip install --upgrade pip setuptools wheel

# ROCm + PyTorch (TheRock, include torchaudio for resolver; remove later)
ARG ROCM_INDEX=https://d2awnip2yjpvqn.cloudfront.net/v2/gfx1151/
RUN python -m pip install --index-url ${ROCM_INDEX} 'rocm[libraries,devel]' && \
    python -m pip install --index-url ${ROCM_INDEX} \
      torch torchvision torchaudio==2.7.1a0 pytorch-triton-rocm numpy

WORKDIR /opt

# Flash-Attention
ENV FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE"


RUN pip install --no-cache-dir packaging && \
    git clone https://github.com/ROCm/flash-attention.git && \
    cd flash-attention && \
    git checkout main_perf && \
    python setup.py install && \
    cd /opt && rm -rf /opt/flash-attention

# VibeVoice
RUN git clone --depth=1 https://github.com/kyuz0/VibeVoice /opt/VibeVoice && \
    cd /opt/VibeVoice && python -m pip install --prefer-binary -e .

# CSM-1B
COPY scripts/csm-1b.py /opt/csm

# Permissions & trims (keep compilers/headers)
RUN chmod -R a+rwX /opt && chmod +x /opt/*.sh || true && \
    find /opt/venv -type f -name "*.so" -exec strip -s {} + 2>/dev/null || true && \
    find /opt/venv -type d -name "__pycache__" -prune -exec rm -rf {} + && \
    python -m pip cache purge || true && rm -rf /root/.cache/pip || true && \
    dnf clean all && rm -rf /var/cache/dnf/*

# ROCm/Triton env (exports TRITON_HIP_* and LD_LIBRARY_PATH; also FA enable)
COPY scripts/01-rocm-env-for-triton.sh /etc/profile.d/01-rocm-env-for-triton.sh

# Banner script (runs on login). Use a high sort key so it runs after venv.sh and 01-rocm-env...
COPY scripts/99-toolbox-banner.sh /etc/profile.d/99-toolbox-banner.sh
RUN chmod 0644 /etc/profile.d/99-toolbox-banner.sh

# Keep /opt/venv/bin first after user dotfiles
COPY scripts/zz-venv-last.sh /etc/profile.d/zz-venv-last.sh
RUN chmod 0644 /etc/profile.d/zz-venv-last.sh

# Disable core dumps in interactive shells (helps with recovering faster from ROCm crashes)
RUN printf 'ulimit -S -c 0\n' > /etc/profile.d/90-nocoredump.sh && chmod 0644 /etc/profile.d/90-nocoredump.sh

CMD ["/bin/bash"]

