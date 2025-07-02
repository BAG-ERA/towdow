FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git curl unzip openjdk-17-jdk \
    fuse libfuse2 desktop-file-utils \
    ninja-build build-essential cmake clang pkg-config \
    libgtk-3-dev libsecret-1-dev

# Install Flutter SDK
ARG FLUTTER_VERSION
ARG ANDROID_TOOL_VERSION_X
ARG ANDROID_TOOL_VERSION
RUN echo "--- Build Arguments ---" && \
    echo "FLUTTER_VERSION: ${FLUTTER_VERSION}" && \
    echo "ANDROID_TOOL_VERSION_X: ${ANDROID_TOOL_VERSION_X}" && \
    echo "ANDROID_TOOL_VERSION: ${ANDROID_TOOL_VERSION}" && \
    echo "-----------------------"
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:$PATH"
RUN flutter doctor

# Install Android SDK
ENV ANDROID_HOME="/usr/local/android-sdk"
RUN mkdir -p $ANDROID_HOME
RUN curl -o /tmp/commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip /tmp/commandlinetools.zip -d $ANDROID_HOME/cmdline-tools && \
    mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest
ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools" "build-tools;${ANDROID_TOOL_VERSION}" "platforms;android-${ANDROID_TOOL_VERSION_X}"

# Clean up apt cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
