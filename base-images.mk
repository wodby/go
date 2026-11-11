# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := golang
BASE_IMAGE_VERSION_SUFFIX := -alpine

BASE_IMAGE_DIGEST_1.26.10-alpine := sha256:87c65a688975c0b1d4585d204874c45ca78354670e3a5f11368c5a492303d696
BASE_IMAGE_DIGEST_1.27.4-alpine := sha256:0a5f7fe796599ff487605987432e7619ae45beeb2fba4c2ce0b907879932aebf

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
