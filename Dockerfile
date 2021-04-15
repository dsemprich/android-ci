# This Dockerfile creates a static build image for CI

# after two days of trying to install Android SDK without knowing anything about android development
# I've resulted to use existing up to date (even though not too popular) docker image
# https://github.com/menny/docker_android
FROM adoptopenjdk/openjdk8:alpine
LABEL maintainer="David Semprich <david-semprich@hell-gutmann.com>"
LABEL description="Android NDK based on kmindi/android-ci"

ENV ANDROID_SDK_ROOT "/android-sdk"
ENV ANDROID_HOME "${ANDROID_SDK_ROOT}"
ENV ANDROID_BUILD_TOOLS "29.0.3"
ENV ANDROID_SDK_TOOLS "25.2.5"
ENV VERSION_TOOLS "6858069"
ENV ANDROID_SDK_URL https://dl.google.com/android/repository/commandlinetools-linux-${VERSION_TOOLS}_latest.zip
# emulator is in its own path since 25.3.0 (not in sdk tools anymore)
ENV PATH "$PATH:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator"

WORKDIR /

SHELL ["/bin/sh", "-c"]

RUN apk update && apk upgrade && apk add --no-cache bash git cmake unzip wget \
curl libvirt-daemon qemu-img qemu-system-x86_64 dbus polkit virt-manager

# Workaround for host bitness error with android emulator
# https://stackoverflow.com/a/37604675/455578
RUN mv /bin/sh /bin/sh.backup \
  && cp /bin/bash /bin/sh

# Add tools from travis
ADD https://raw.githubusercontent.com/travis-ci/travis-cookbooks/ca800a93071a603745a724531c425a41493e70ff/community-cookbooks/android-sdk/files/default/android-wait-for-emulator /usr/local/bin/android-wait-for-emulator
RUN chmod +x /usr/local/bin/android-wait-for-emulator

# Add own tools
COPY assure_emulator_awake.sh /usr/local/bin/assure_emulator_awake.sh
RUN chmod +x /usr/local/bin/assure_emulator_awake.sh

RUN curl -s https://dl.google.com/android/repository/commandlinetools-linux-${VERSION_TOOLS}_latest.zip > /cmdline-tools.zip \
 && mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
 && unzip /cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
 && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
 && rm -v /cmdline-tools.zip

RUN mkdir -p $ANDROID_SDK_ROOT/licenses/ \
 && echo "8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01fb78af6dfcb131a6481e\n24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_SDK_ROOT/licenses/android-sdk-license \
 && echo "84831b9409646a918e30573bab4c9c91346d8abd\n504667f4c0de7af1a06de9f4b1727b84351f2910" > $ANDROID_SDK_ROOT/licenses/android-sdk-preview-license \
 && yes | sdkmanager --licenses >/dev/null

RUN mkdir -p /root/.android \
 && touch /root/.android/repositories.cfg \
 && sdkmanager --update

# Update platform and build tools
RUN yes | sdkmanager "build-tools;${ANDROID_BUILD_TOOLS}" && \
# Update emulators
sdkmanager "system-images;android-25;google_apis;x86_64" "system-images;android-25;google_apis;arm64-v8a" && \
sdkmanager "platforms;android-25" && \
# Update SDKs
sdkmanager "platforms;android-29" && \
sdkmanager "platform-tools" && \
sdkmanager "extras;android;m2repository" && \
sdkmanager "extras;google;m2repository" && \
# Constraint Layout
sdkmanager "extras;m2repository;com;android;support;constraint;constraint-layout;1.0.2" && \
sdkmanager "extras;m2repository;com;android;support;constraint;constraint-layout-solver;1.0.2" && \
# NDK
sdkmanager "ndk;21.0.6113669"

# echo actually installed Android SDK packages
RUN sdkmanager --list
