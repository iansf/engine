// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef SKY_SHELL_TESTING_TEST_RUNNER_H_
#define SKY_SHELL_TESTING_TEST_RUNNER_H_

#include <string>

#include "base/macros.h"
#include "base/memory/weak_ptr.h"
#include "mojo/common/binding_set.h"
#include "mojo/public/cpp/application/interface_factory_impl.h"
#include "sky/services/engine/sky_engine.mojom.h"
#include "sky/services/testing/test_harness.mojom.h"

namespace sky {
namespace shell {
class ShellView;

class TestRunner : public mojo::InterfaceFactory<TestHarness>,
                   public TestHarness {
 public:
  static TestRunner& Shared();

  void set_package_root(const std::string& package_root) {
    package_root_ = package_root;
  }

  struct SingleTest {
    std::string path;
    bool is_snapshot = false;
  };

  void Start(scoped_ptr<SingleTest> single_test);

  // mojo::InterfaceFactory<TestHarness> implementation:
  void Create(mojo::ApplicationConnection* app,
              mojo::InterfaceRequest<TestHarness> request) override;

 private:
  // TestHarness implementation:
  void OnTestComplete(const mojo::String& test_result,
                      const mojo::Array<uint8_t> pixels) override;
  void DispatchInputEvent(mojo::EventPtr event) override;

  TestRunner();
  ~TestRunner() override;
  void ScheduleRun();
  void Run();

  std::string package_root_;
  scoped_ptr<ShellView> shell_view_;
  SkyEnginePtr sky_engine_;

  scoped_ptr<SingleTest> single_test_;
  mojo::BindingSet<TestHarness> bindings_;

  base::WeakPtrFactory<TestRunner> weak_ptr_factory_;

  DISALLOW_COPY_AND_ASSIGN(TestRunner);
};

}  // namespace shell
}  // namespace sky

#endif  // SKY_SHELL_TESTING_TEST_RUNNER_H_
