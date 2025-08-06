make test
dagger call build-and-publish \
    --username="airiksarkivet" \
    --password="..." \ # insert pw
    --source="./Riksarkivets-Development-Template" \
    --enable-cuda="true" \
    --image-tag="v14.2.0" \
    --registry="docker.io" \
    --image-repository="riksarkivet/coder-workspace-ml"
