var $ = jQuery;
jQuery(document).ready(function($) {

    let web3 = null;
    let tokenContract = null;
    let airdropContract = null;


    setTimeout(init, 1000);
    //$(window).on("load", init);

    async function init(){
        web3 = await loadWeb3();
        if(web3 == null) {
            setTimeout(init, 5000);
            return;
        }
        loadContract('./build/contracts/BOBPToken.json', function(data){
            tokenContract = data;
            $('#tokenABI').text(JSON.stringify(data.abi));
        });
        loadContract('./build/contracts/BOBPAirdrop.json', function(data){
            airdropContract = data;
            $('#airdropABI').text(JSON.stringify(data.abi));
            initAirdropForm();
        });
    }

    function initAirdropForm(){
        let airdropAddress = getUrlParam('airdrop');
        if(web3.utils.isAddress(airdropAddress)){
            $('input[name=airdropAddress]', '#airdropExecuteForm').val(airdropAddress);
            $('#loadInfo').click();
        }
    }

    $('#publishAirdrop').click(function(){
        printError('');
        let form = $('#airdropContractForm');

        let airdropObj = new web3.eth.Contract(airdropContract.abi);
        airdropObj.deploy({
            data: airdropContract.bytecode,
        })
        .send({
            from: web3.eth.defaultAccount,
        })
        .on('error',function(error){
            console.log('Publishing failed: ', error);
            printError(error);
        })
        .on('transactionHash',function(tx){
            $('input[name=publishedTx]',form).val(tx);
        })
        .on('receipt',function(receipt){
            $('input[name=publishedAddress]',form).val(receipt.contractAddress);
            $('input[name=airdropAddress]','#airdropExecuteForm').val(receipt.contractAddress);
        })
        .then(function(contractInstance){
            //console.log(contractInstance.options.address) // instance with the new contract address
            return contractInstance.methods.token().call()
            .then(function(result){
                $('input[name=tokenAddress]',form).val(result);
            });
        });
    });

    $('#loadInfo').click(function(){
        let form = $('#airdropExecuteForm');
        let airdropInstance = loadContractInstance(airdropContract, $('input[name=airdropAddress]',form).val());
        airdropInstance.methods.token().call()
        .then(function(result){
            $('input[name=tokenAddress]',form).val(result);
            return result;
        })
        .then(function(tokenAddress){
            let tokenInstance = loadContractInstance(tokenContract, tokenAddress);
            return tokenInstance.methods.totalSupply().call()
            .then(function(result){
                $('input[name=totalSupply]',form).val(result);
            });
        });

    });

    $('#parseList').click(function(){
        let form = $('#airdropExecuteForm');
        let addressesText = $('#unparsedAddresses').val();
        let parsed = new Array();
        let parseLog = $('#parseLog');
        parseLog.html('');
        addressesText.split('\n').forEach(function(elem, idx){
            let addr = elem.trim();
            if(web3.utils.isAddress(addr)){
                parsed.push(addr);
            }else{
                if(!addr.startsWith('0x') || addr.length != 42){
                    parseLog.append('<div>Line '+(idx+1)+': <i>"'+elem+'"</i> is not an ethereum address</div>')    
                }else{
                    let addrFix = addr.toLowerCase();
                    if(web3.utils.isAddress(addrFix)){
                        parseLog.append('<div>Line '+(idx+1)+': <i>'+addr+'</i> has wrong checksumm</div>')    
                    }
                }
            }
        });
        parseLog.append('Correctly parsed: '+parsed.length);
        $('#parsedAddresses').val(JSON.stringify(parsed));
    });

    $('#executeAirdrop').click(function(){
        let form = $('#airdropExecuteForm');
        let airdropLog = $('#airdropLog');
        airdropLog.html('');
        let sendStart = Number($('input[name=sendStart]', form).val());
        let sendLimit = Number($('input[name=sendLimit]', form).val());
        if(Number(sendLimit) <= 0) {
            console.log('Bad send limit: '+sendLimit); return;
        }

        let airdropInstance = loadContractInstance(airdropContract, $('input[name=airdropAddress]',form).val());
        let airdropAmount = web3.utils.toWei($('input[name=amount]', form).val(), 'ether');
        let addresses = JSON.parse($('#parsedAddresses').val());
        if(typeof addresses != 'object' || addresses.length == 0){
            console.error('Can not parse addresses');
            return;
        }
        airdropLog.append('<div>Starting airdrop '+web3.utils.fromWei(airdropAmount) +' BOBP to '+addresses.length+' addresses in batches of '+sendLimit+' addresses per transaction, starting from address '+sendStart+'.</div>');
        function sendTokens(start) {
            let end = start+sendLimit;
            if(start >= end) {
                console.error('Start >= End!', start, sendLimit, end); return;
            }
            let addressList = addresses.slice(start, start+sendLimit);
            console.log('Send '+airdropAmount+' tokens to addresses '+start+' - '+end, addressList);
            let tx = null;
            airdropInstance.methods.airdrop(airdropAmount, addressList).send({
                from: web3.eth.defaultAccount,
            })
            .on('transactionHash', function(hash){
                tx = hash;
                airdropLog.append('<div>Transaction <i>'+tx+'</i>: addresses '+start+' - '+end+' published.</div>');
                sendTokens(end);
            })
            .on('receipt', function(receipt){
                airdropLog.append('<div>Transaction <i>'+receipt.transactionHash+'</i> ('+start+' - '+end+') mined.</div>');
            })
            .on('error', function(error){
                console.log('Error sending to addresses '+start+' - '+end+((tx==null)?'':', tx '+tx), error);
            });
        }
        sendTokens(0);

    });

    //====================================================

    async function loadWeb3(){
        printError('');
        if(typeof window.web3 == "undefined"){
            printError('No MetaMask found');
            return null;
        }
        // let Web3 = require('web3');
        // let web3 = new Web3();
        // web3.setProvider(window.web3.currentProvider);
        let web3 = new Web3(window.web3.currentProvider);

        let accounts = await web3.eth.getAccounts();
        if(typeof accounts[0] == 'undefined'){
            printError('Please, unlock MetaMask');
            return null;
        }
        // web3.eth.getBlock('latest', function(error, result){
        //     console.log('Current latest block: #'+result.number+' '+timestmapToString(result.timestamp), result);
        // });
        web3.eth.defaultAccount =  accounts[0];
        window.web3 = web3;
        return web3;
    }
    function loadContract(url, callback){
        $.ajax(url,{'dataType':'json', 'cache':'false', 'data':{'t':Date.now()}}).done(callback);
    }

    function loadContractInstance(contractDef, address){
        if(typeof contractDef == 'undefined' || contractDef == null) return null;
        printError('');
        if(!web3.utils.isAddress(address)){printError('Contract '+contractDef.contract_name+' address '+address+'is not an Ethereum address'); return null;}
        return new web3.eth.Contract(contractDef.abi, address);
    }
    /**
    * Take GET parameter from current page URL
    */
    function getUrlParam(name){
        if(window.location.search == '') return null;
        let params = window.location.search.substr(1).split('&').map(function(item){return item.split("=").map(decodeURIComponent);});
        let found = params.find(function(item){return item[0] == name});
        return (typeof found == "undefined")?null:found[1];
    }


    function printError(msg){
        if(msg == null || msg == ''){
            $('#errormsg').html('');    
        }else{
            console.error(msg);
            $('#errormsg').html(msg);
        }
    }
});
