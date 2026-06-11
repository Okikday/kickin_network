## 0.0.1-dev.19
- Fixed the response to propagate data even when it throws where you use any of the catchErrorOnSend in the requests.

## 0.0.1-dev.18
- Fixed error where globalErrorOverride still throws even when server returns an error

## 0.0.1-dev.17
- Fixed critical mistake where we assumed [message] to be a substitute for [error] in the globalErrorOverride

## 0.0.1-dev.16
- Fixed error handling in KRestApiBase.globalErrorOverride
- Breaking changes: Response to be passed in globalErrorOverride instead of dynamic
- Added an error factory for KResponse

## 0.0.1-dev.15
- Improved error handling in KRestApiBase.globalErrorOverride
- Made baseUrl accessible in KRestApiBase
## 0.0.1-dev.14
- Added an extra logError arg to the [LogOptions] to better control what gets logged
- Improved exception handling in KRestApiBase

## 0.0.1-dev.13
- Improved error handling with KRestApiBase.globalErrorOverride

## 0.0.1-dev.12
- Improved default error handling in KRestApiBase.globalErrorOverride

## 0.0.1-dev.11
- Correct error handling in ApiResult.transform method

## 0.0.1-dev.10
- Improved code efficiency

## 0.0.1-dev.9
- Added KUriRequest classes
- Added logging query for response

## 0.0.1-dev.8
- Export missing classes

## 0.0.1-dev.7
- Breaking change: Unified all methods on the KRestRequest classes to use similar methods for requests
- Updated ApiResult to a class from Record (breaking*)
- Updated documentation

## 0.0.1-dev.6
- Improved stacktrace logging

## 0.0.1-dev.5
- Added a try(RequestType)Result function for all KRestRequest classes

## 0.0.1-dev.4
- Improved error handling by adding [errorOverride] params for the KRestRequest classes and allowing override on the global api base

## 0.0.1-dev.3
- Fixed docs

## 0.0.1-dev.2
- No details

## 0.0.1-dev.1
- Abstracted away from kickin