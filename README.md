# amazonlinux-builder-buildpackless-base
A Cloud Native Buildpack (CNB) builder with amazonlinux 2023 stack **without** buildpacks

This builder uses the amazonlinux stack built from [here](https://github.com/jericop/amazonlinux-stack).

docker hub image URI:
    * `jericop/amazonlinux-builder:latest`

## Creating the builder

Download the pack cli tool [here](https://buildpacks.io/docs/tools/pack/).

```
pack builder create jericop/amazonlinux-builder:latest -c builder.toml
```