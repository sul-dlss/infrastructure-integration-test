# Test Suite Reliability Improvements

This document outlines the changes made to improve test suite reliability when run together.

## Changes Made

### 1. Session Isolation (`spec_helper.rb`)
- Added `before(:each)` hook to reset Capybara sessions
- Added `after(:each)` hook to clean up browser sessions and authentication state
- Added suite-level monitoring for timing insights

### 2. Authentication State Management (`authentication_helpers.rb`)
- Replaced `mattr_accessor` with module variables for better isolation
- Added `reset_authentication_state!` method for cleanup
- Added explicit session reset in `authenticate!` method

### 3. Browser Console Logging (`capybara.rb`)
- Fixed Rails.logger reference (not available in this context)
- Only capture browser logs on test failures to reduce noise
- Added error handling for browser log retrieval

### 4. Cleanup Helpers (`cleanup_helpers.rb`)
- New module for tracking and cleaning up test artifacts
- Supports tracking DRUIDs and temporary files
- Provides `track_created_objects` class method for automatic cleanup

### 5. Download Helpers (`download_helpers.rb`)
- Enhanced error handling in cleanup methods
- Added automatic download cleanup after each test
- More robust file deletion with existence checks

## Usage Guidelines

### For new tests:
```ruby
RSpec.describe 'Your Test' do
  include CleanupHelpers
  track_created_objects

  scenario do
    # ... test logic ...
    object_druid = create_test_object
    track_druid(object_druid) # Track for cleanup
    # ... rest of test ...
  end
end
```

### For temporary files:
```ruby
track_temp_file('/path/to/temp/file.csv')
```

## Benefits

1. **Test Isolation**: Each test starts with a clean browser session and authentication state
2. **Consistent State**: No shared state between tests prevents interference
3. **Automatic Cleanup**: Test artifacts are tracked and cleaned up automatically
4. **Better Debugging**: More informative logging for failures and cleanup operations
5. **Reduced Flakiness**: Eliminated timing dependencies from persistent sessions

## Future Improvements

- Implement actual API-based cleanup for DRUIDs (currently logs cleanup intention)
- Add configuration options for cleanup behavior
- Consider parallel test execution safety
- Add metrics collection for test timing and failure patterns
