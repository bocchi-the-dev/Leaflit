![meow](https://github.com/bocchi-the-dev/banners/blob/main/explore00.png?raw=true)

## Dependencies:
- aria2c
- cURL
- java

## Remember:
- As of now, the maximum resolution of the GIF is 480x480. It's not a problem to 
have high res stuff but it won't fit inside the GIF/Picture window in AOD Screen.

## To build:

- [#0] Give permissions to the script file
```
chmod +x ./src/leaflit.sh
```

- [#1] Edit leaflit.conf for automation (optional)

- [#2] Execute the script
```
./src/leaflit.sh
```

## Automation (optional):
- If you want to automate this script's process, you can always edit the `leaflit.conf` present in the source.

| Variable | Description |
|---------|-------------|
| `maxGIFIndex` | The maximum amount of GIF you want to replace. Maximum is 20. |
| `androidSDKVersion` | Set the correct corresponding SDK version. Find the SDK version of your ROM by searching "Android xx SDK version" on google. |
| `skipAPKSign` | Skips signing if you set this to true. |
| `gifPaths` | An array that contains path to the GIFS. Be sure to add paths to the array. |

#### Please fill out the `MY_KEYSTORE_ALIAS`, `MY_KEYSTORE_PASSWORD`, `MY_KEYSTORE_PATH`, `MY_KEYSTORE_ALIAS_KEY_PASSWORD`. This is optional but this can be used to sign package automatically!