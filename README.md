# amazonlinux-builder-buildpackless-base
A Cloud Native Buildpack (CNB) builder with amazonlinux stack **without** buildpacks

This builder uses the amazonlinux stack built from [here](https://github.com/jericop/amazonlinux-stack).

docker hub image URI:
    * `jericop/amazonlinux-builder:base`

## Creating the builder

Download the pack cli tool [here](https://buildpacks.io/docs/tools/pack/).

```
pack builder create jericop/amazonlinux-builder:base -c builder.toml
```