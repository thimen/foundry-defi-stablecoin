// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployDsc} from "script/DeployDsc.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDsc deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;
    address btcUsdPriceFeed;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant DSC_TO_MINT_DIVIDER = 3; //ex. 3 = AMOUNT_COLLATERAL/3

    uint256 amountCollateral = 10 ether;
    uint256 amountDscToMint;
    address public user = address(1);

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dscEngine, config) = deployer.run();

        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ////////////////////////////////
    // Constructor Tests          //
    ////////////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedsAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedsAddresses.push(ethUsdPriceFeed);
        priceFeedsAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__tokenAddressesAndPriceFeedAddressMustBeSameLength.selector);

        new DSCEngine(tokenAddresses, priceFeedsAddresses, address(dsc));
    }

    function testDSCEngineConstructorSetsCorrectValues() public {
        tokenAddresses.push(weth);
        priceFeedsAddresses.push(ethUsdPriceFeed);

        dscEngine = new DSCEngine(tokenAddresses, priceFeedsAddresses, address(dsc));

        address[] memory actualTokenAddresses = dscEngine.getTokenAddresses();

        assert(actualTokenAddresses.length == 1);
        assert(actualTokenAddresses[0] == weth);
        assert(priceFeedsAddresses[0] == dscEngine.getPriceFeedAddress(weth));
    }

    ///////////////////
    // Price Tests   //
    ///////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15 ether;

        uint256 expectedEthUsdValue = 2000 * ethAmount;
        uint256 actualEthUsdValue = dscEngine.getUsdValue(weth, ethAmount);

        assert(expectedEthUsdValue == actualEthUsdValue);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(weth, usdAmount);

        assert(expectedWeth == actualWeth);
    }

    ////////////////////////////////
    // Deposit Collateral Tests   //
    ////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.prank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RanToken", "RAN", USER, AMOUNT_COLLATERAL);
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        amountDscToMint = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / DSC_TO_MINT_DIVIDER;
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountDscToMint);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralValueInUsd = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(weth, totalCollateralValueInUsd);

        assert(expectedTotalDscMinted == totalDscMinted);
        assert(expectedCollateralValueInUsd == totalCollateralValueInUsd);
        assert(expectedDepositAmount == AMOUNT_COLLATERAL);
    }

    function testRedeemCollateralForDscBurnsAndRedeemsCollateral() public depositedCollateralAndMintDsc {
        (uint256 initialTotalDscMinted,) = dscEngine.getAccountInformation(USER);

        vm.startPrank(USER);
        dsc.approve(address(dscEngine), 6666666666666666666666);
        dscEngine.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, initialTotalDscMinted);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralValueInUsd = 0;

        assert(expectedTotalDscMinted == totalDscMinted);
        assert(expectedCollateralValueInUsd == totalCollateralValueInUsd);
    }

    ////////////////////////////////
    // Mint Dsc Tests             //
    ////////////////////////////////

    function testMintUsdRevertsIfAmountIsZero() public depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.mintDsc(0);
    }

    function testMintDscMintsCorrectAmountOfDsc() public depositedCollateral {
        amountDscToMint = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / DSC_TO_MINT_DIVIDER;
        vm.prank(USER);
        dscEngine.mintDsc(amountDscToMint);

        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);

        assert(amountDscToMint == totalDscMinted);
    }

    function testMintDscRevertsIfHealthFactorBroken() public depositedCollateral {
        uint256 allCollateralToDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 amountCollateralToUsd = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 expectedHealthFactor = dscEngine.calculateHealthFactor(allCollateralToDsc, amountCollateralToUsd);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorTooLow.selector, expectedHealthFactor));
        vm.prank(USER);
        dscEngine.mintDsc(allCollateralToDsc);
    }

    ////////////////////////////////
    // Healthfactor Tests         //
    ////////////////////////////////

    function testHealthFactorMaxWhenNoDebt() public depositedCollateral {
        uint256 healthFactor = dscEngine.getHealthFactor(USER);
        assertEq(healthFactor, type(uint256).max);
    }

    function testHealthFactorReturnsCorrectValue() public depositedCollateral {
        uint256 halfOfCollateralInUsd = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / 2;
        vm.prank(USER);
        dscEngine.mintDsc(halfOfCollateralInUsd);

        uint256 collateralValueInUsd = dscEngine.getAccountCollateralValueInUsd(USER);

        uint256 expectedHealthFactor = dscEngine.calculateHealthFactor(halfOfCollateralInUsd, collateralValueInUsd);
        uint256 actualHealthFactor = dscEngine.getHealthFactor(USER);

        assert(expectedHealthFactor == actualHealthFactor);
    }

    function testHealthFactorDropsWhenCollateralPriceFalls() public depositedCollateralAndMintDsc {
        int256 newPrice = 1000e8; // New price for ETH is $1000

        uint256 initialHealthFactor = dscEngine.getHealthFactor(USER);

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(newPrice);

        uint256 newHealthFactor = dscEngine.getHealthFactor(USER);
        assertLt(newHealthFactor, initialHealthFactor);
    }

    ////////////////////////////////
    // Burn Dsc Tests             //
    ////////////////////////////////

    function testBurnDscRevertsIfAmountIsZero() public depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        vm.prank(USER);
        dscEngine.burnDsc(0);
    }

    function testBurnDscRemovesDscFromUser() public depositedCollateralAndMintDsc {
        uint256 amountDscToBurn = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / DSC_TO_MINT_DIVIDER;
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), amountDscToBurn);
        dscEngine.burnDsc(amountDscToBurn);
        vm.stopPrank();
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);

        assert(0 == totalDscMinted);
    }

    ////////////////////////////////
    // Liquidation Tests          //
    ////////////////////////////////

    function testLiquidationFailsForHealthyAccount() public depositedCollateralAndMintDsc {
        uint256 amountToLiquidate = amountDscToMint / 2;

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        vm.prank(USER);
        dscEngine.liquidate(weth, USER, amountToLiquidate);
    }

    ////////////////////////////////
    // Redeem Collateral Tests    //
    ////////////////////////////////

    function testRedeemCollateralClearsAccount() public depositedCollateralAndMintDsc {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 tokenCollateralAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        vm.startPrank(USER);
        dsc.approve(address(dscEngine), amountDscToMint);
        dscEngine.redeemCollateralForDsc(weth, tokenCollateralAmount, totalDscMinted);
        vm.stopPrank();

        (uint256 totalAfterDscMinted, uint256 totalCollateralValueInUsdAfter) = dscEngine.getAccountInformation(USER);

        assertEq(totalAfterDscMinted, 0);
        assertEq(totalCollateralValueInUsdAfter, 0);
    }
}
