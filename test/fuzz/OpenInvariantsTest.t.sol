// //SPDX-License-Identifier: MIT

// // Have our invariants aka properties

// //What are our invariants?

// // 1. The total supply of DSC should be less than then total value of collateral
// // 2. Getter view functions should never revert <- evergreen invariant

// pragma solidity ^0.8.18;

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDsc} from "script/DeployDSC.s.sol";
// import {DSCEngine} from "src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//     DSCEngine public dscEngine;
//     DecentralizedStableCoin public dsc;
//     HelperConfig public config;
//     address ethUsdPriceFeed;
//     address weth;
//     address btcUsdPriceFeed;
//     address wbtc;

//     // address public USER = makeAddr("user");
//     // uint256 public constant STARTING_ERC20_BALANCE = 100 ether;
//     // uint256 public constant AMOUNT_COLLATERAL = 10 ether;
//     // uint256 public constant DSC_TO_MINT_DIVIDER = 3; //ex. 3 = AMOUNT_COLLATERAL/3

//     function setUp() external {
//         DeployDsc deployer = new DeployDsc();
//         (dsc, dscEngine, config) = deployer.run();

//         (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(dscEngine));

//         // ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
//     }

//     function invariant_protocolMustHaveMoreCollateralValueThanTotalSupplyDsc() public view {
//         uint256 totalSupplyDsc = dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
//         uint256 totalwBtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

//         uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = dscEngine.getUsdValue(wbtc, totalwBtcDeposited);

//         console.log("totalSupplyDsc: ", totalSupplyDsc);
//         console.log("totalWethValue: ", wethValue);
//         console.log("totalwBtcValue: ", wbtcValue);

//         assert(wethValue + wbtcValue >= totalSupplyDsc);
//     }
// }
